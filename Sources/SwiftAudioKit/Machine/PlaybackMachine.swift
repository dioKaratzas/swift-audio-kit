//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// The whole behaviour of the player, as a synchronous function of its inputs.
/// It never awaits; everything asynchronous leaves as an `Effect` for someone else to run.
struct PlaybackMachine: Sendable {
    private(set) var state = PlaybackState.idle
    private(set) var intent = PlaybackIntent.pause
    private(set) var quality: AudioQuality
    private(set) var queue = PlaybackQueue()
    private(set) var progress = PlaybackProgress.zero
    private(set) var metadata = AudioMetadata()
    private(set) var network = NetworkStatus.unknown

    /// Stamped onto every effect that resolves later, so a result for a track the listener
    /// has already skipped past is discarded instead of clobbering the current one.
    private(set) var generation = 0

    var configuration: AudioPlayerConfiguration
    var metadataParser: any MetadataParser = DefaultMetadataParser()
    private var skipped = Set<AudioItem.ID>()
    private var retryCount = 0
    private var interruptionCount = 0

    init(configuration: AudioPlayerConfiguration = .default) {
        self.configuration = configuration
        quality = configuration.defaultQuality
    }

    mutating func handle(_ signal: Signal) -> [Effect] {
        switch signal {
        case .play: resume()
        case .pause: pause(reason: .user)
        case .stop: stop()
        case let .playItems(items, index): playItems(items, startingAt: index)
        case let .append(items): append(items)
        case let .insertNext(item): queue.insertNext(item)
        case let .remove(id): remove(id)
        case let .move(from, to): queue.move(from: from, to: to)
        case .removeAll: clearQueue()
        case let .jump(id): jump(to: id)
        case .next: advance(userInitiated: true)
        case .previous: retreat()
        case let .seeked(time): progress.elapsed = time
        case let .setQuality(quality): change(to: quality)
        case let .setMode(mode): setMode(mode)
        case let .setSkipped(ids): skipped = ids; return []
        case let .engine(signal): return handle(engine: signal)
        case let .network(status): return handle(network: status)
        case let .sessionFailed(error): fail(with: error)
        case let .interrupted(reason): interrupt(reason)
        case let .interruptionEnded(shouldResume): endInterruption(shouldResume: shouldResume)
        case let .retryDue(generation): retry(generation: generation)
        case let .connectionLossDeadlineReached(generation): connectionLossExpired(generation: generation)
        case .qualityUpgradeDue: upgradeQuality()
        }
        return drain()
    }

    // MARK: Transport

    private mutating func resume() {
        intent = .play
        guard let item = state.item else {
            advance(userInitiated: true)
            return
        }
        guard !state.isPlaying else {
            return
        }
        if state.isFailed {
            startPlaying(item)
        } else {
            effects.append(.play)
        }
    }

    private mutating func pause(reason: PauseReason) {
        intent = .pause
        effects.append(.cancelRetry)
        guard let item = state.item, !state.isPaused else {
            return
        }
        transition(to: .paused(item, reason: reason))
        effects.append(.pause)
    }

    private mutating func stop() {
        intent = .pause
        invalidate()
        transition(to: .idle)
        effects.append(contentsOf: [.unload, .cancelRetry, .cancelConnectionLossTimer, .deactivateSession])
    }

    private mutating func playItems(_ items: [AudioItem], startingAt index: Int) {
        queue = PlaybackQueue(items: items, mode: queue.mode)
        intent = .play

        guard !items.isEmpty else {
            fail(with: .noPlayableItems)
            return
        }
        if items.indices.contains(index), let item = queue.jump(to: items[index].id) {
            startPlaying(item)
        } else {
            advance(userInitiated: true)
        }
    }

    private mutating func append(_ items: [AudioItem]) {
        queue.append(contentsOf: items)
    }

    private mutating func remove(_ id: AudioItem.ID) {
        let wasPlaying = state.item?.id == id
        queue.remove(id: id)

        guard wasPlaying else {
            return
        }
        if let next = queue.current {
            startPlaying(next)
        } else {
            stop()
        }
    }

    private mutating func clearQueue() {
        queue.removeAll()
        stop()
    }

    private mutating func jump(to id: AudioItem.ID) {
        guard let item = queue.jump(to: id) else {
            return
        }
        intent = .play
        startPlaying(item)
    }

    private mutating func advance(userInitiated: Bool) {
        guard let item = queue.advance(skipping: skipped) else {
            if userInitiated || intent == .play {
                effects.append(.emit(.queueExhausted))
            }
            stop()
            return
        }
        startPlaying(item)
    }

    private mutating func retreat() {
        guard let item = queue.retreat(skipping: skipped) else {
            effects.append(.seek(to: .zero, generation: generation))
            return
        }
        startPlaying(item)
    }

    private mutating func startPlaying(_ item: AudioItem) {
        let previous = state.item
        invalidate()
        retryCount = 0
        progress = .zero
        metadata = item.metadata

        guard network.isUsable || item.isLocal else {
            transition(to: .waitingForConnection(item))
            effects.append(.startConnectionLossTimer(
                deadline: configuration.maximumConnectionLossTime,
                generation: generation
            ))
            return
        }

        transition(to: .loading(item))
        if previous?.id != item.id {
            effects.append(.emit(.itemChanged(from: previous, to: item)))
        }
        effects.append(contentsOf: [
            .activateSession,
            .beginBackgroundActivity,
            .load(request(for: item), generation: generation)
        ])
    }

    /// Metered and Low Data Mode links get the reduced ceiling when one is configured.
    private var preferredPeakBitRate: Double? {
        let buffering = configuration.buffering
        guard network.prefersReducedData else {
            return buffering.preferredPeakBitRate
        }
        return buffering.preferredPeakBitRateOnExpensiveNetworks ?? buffering.preferredPeakBitRate
    }

    private func request(for item: AudioItem) -> PlaybackRequest {
        PlaybackRequest(
            url: item.sources.resolve(preferring: quality).url,
            preferredForwardBufferDuration: configuration.buffering.preferredForwardDuration,
            preferredPeakBitRate: preferredPeakBitRate
        )
    }

    // MARK: Engine

    private mutating func handle(engine signal: EngineSignal) -> [Effect] {
        guard let item = state.item else {
            return drain()
        }

        switch signal {
        case .statusChanged(.ready):
            effects.append(.endBackgroundActivity)
            if intent == .play {
                transition(to: .playing(item))
                effects.append(.play)
            } else {
                transition(to: .paused(item, reason: .user))
            }

        case let .statusChanged(.failed(failure)), let .failed(failure):
            handleFailure(failure, for: item)

        case let .timeControlChanged(control):
            handle(timeControl: control, for: item)

        case let .playheadMoved(elapsed):
            progress.elapsed = elapsed

        case let .durationResolved(duration):
            progress.duration = duration
            effects.append(.emit(.durationResolved(duration, for: item.id)))

        case let .bufferChanged(loaded, seekable):
            progress.buffered = loaded
            progress.seekable = seekable

        case .reachedEnd:
            effects.append(.emit(.itemFinished(item)))
            advance(userInitiated: false)

        case let .metadataReceived(entries):
            updateMetadata(from: entries, for: item)

        case let .errorLogged(failure):
            effects.append(.emit(.recoverableErrorLogged(failure)))

        case .statusChanged:
            break
        }

        return drain()
    }

    private mutating func handle(timeControl: EngineTimeControl, for item: AudioItem) {
        switch timeControl {
        case .playing where !state.isPlaying:
            transition(to: .playing(item))
        case .waiting where timeControl.showsLoadingIndicator && state.isPlaying:
            countInterruption()
            transition(to: .buffering(item))
        default:
            break
        }
    }

    private mutating func updateMetadata(from entries: [MetadataEntry], for item: AudioItem) {
        let discovered = metadataParser.metadata(from: entries)
        let merged = item.metadata.filling(from: discovered)
        guard merged != metadata else {
            return
        }
        metadata = merged

        var updated = item
        updated.metadata = merged
        queue.update(updated)
        effects.append(.emit(.metadataUpdated(merged, for: item.id)))
    }

    private mutating func handleFailure(_ failure: PlaybackFailure, for item: AudioItem) {
        guard retryCount < configuration.retry.maximumAttempts else {
            fail(with: .retryLimitReached(attempts: retryCount))
            return
        }
        retryCount += 1
        transition(to: .buffering(item))
        effects.append(.scheduleRetry(after: configuration.retry.timeout, generation: generation))
    }

    private mutating func retry(generation: Int) {
        guard generation == self.generation, let item = state.item else {
            return
        }
        let resume = progress.elapsed
        effects.append(.load(request(for: item), generation: self.generation))
        if resume > .zero {
            effects.append(.seek(to: resume, generation: self.generation))
        }
    }

    // MARK: Network

    private mutating func handle(network status: NetworkStatus) -> [Effect] {
        let previous = network
        network = status
        guard status != previous else {
            return drain()
        }
        effects.append(.emit(.networkChanged(status)))

        if !status.isUsable {
            connectionLost()
        } else if state.isWaitingForConnection {
            connectionRestored()
        }
        return drain()
    }

    private mutating func connectionLost() {
        guard let item = state.item, !item.isLocal, state.isActive, !state.isWaitingForConnection else {
            return
        }
        transition(to: .waitingForConnection(item))
        effects.append(contentsOf: [
            .pause,
            .startConnectionLossTimer(deadline: configuration.maximumConnectionLossTime, generation: generation)
        ])
        countInterruption()
    }

    private mutating func connectionRestored() {
        guard let item = state.item else {
            return
        }
        effects.append(.cancelConnectionLossTimer)
        guard configuration.resumesAfterConnectionLoss || intent == .pause else {
            transition(to: .paused(item, reason: .stalled))
            return
        }
        startPlaying(item)
    }

    private mutating func connectionLossExpired(generation: Int) {
        guard generation == self.generation, state.isWaitingForConnection else {
            return
        }
        fail(with: .connectionLost(after: configuration.maximumConnectionLossTime))
    }

    // MARK: Interruption

    private mutating func interrupt(_ reason: PauseReason) {
        guard let item = state.item, state.isActive else {
            return
        }
        effects.append(.emit(.interrupted(reason)))
        transition(to: .paused(item, reason: reason))
        effects.append(.pause)
    }

    private mutating func endInterruption(shouldResume: Bool) {
        effects.append(.emit(.interruptionEnded(shouldResume: shouldResume)))
        guard shouldResume, configuration.resumesAfterInterruption, intent == .play,
              state.pauseReason?.isAutomatic == true else {
            return
        }
        resume()
    }

    // MARK: Quality

    private mutating func setMode(_ mode: PlaybackMode) {
        queue.mode = mode
    }

    private mutating func change(to newQuality: AudioQuality) {
        guard newQuality != quality else {
            return
        }
        let previous = quality
        quality = newQuality
        effects.append(.emit(.qualityChanged(from: previous, to: newQuality)))

        guard let item = state.item, state.isActive else {
            return
        }
        let resume = progress.elapsed
        invalidate()
        effects.append(.load(request(for: item), generation: generation))
        if resume > .zero {
            effects.append(.seek(to: resume, generation: generation))
        }
    }

    private mutating func countInterruption() {
        guard let threshold = configuration.quality.downgradeAfterInterruptions else {
            return
        }
        interruptionCount += 1
        guard interruptionCount >= threshold, let lower = quality.lower else {
            return
        }
        interruptionCount = 0
        change(to: lower)
    }

    /// Each window re-arms the next one and starts counting stalls again, so a single stall
    /// delays an upgrade rather than preventing every later one.
    private mutating func upgradeQuality() {
        defer {
            interruptionCount = 0
            if let interval = configuration.quality.interval {
                effects.append(.scheduleQualityUpgrade(after: interval))
            }
        }

        guard configuration.quality.isAutomatic, interruptionCount == 0, let higher = quality.higher else {
            return
        }
        change(to: higher)
    }

    // MARK: Bookkeeping

    private var effects = [Effect]()

    private mutating func drain() -> [Effect] {
        defer { effects.removeAll() }
        return effects
    }

    private mutating func transition(to next: PlaybackState) {
        guard next != state else {
            return
        }
        let previous = state
        state = next
        effects.append(.emit(.stateChanged(from: previous, to: next)))

        if previous.isActive, !next.isActive {
            effects.append(.endBackgroundActivity)
        }
    }

    private mutating func fail(with error: AudioPlayerError) {
        invalidate()
        transition(to: .failed(item: state.item, error: error))
        effects.append(contentsOf: [.unload, .cancelRetry, .cancelConnectionLossTimer, .emit(.failed(error))])
    }

    /// Bumps the generation so results still in flight for the previous track are ignored.
    private mutating func invalidate() {
        generation += 1
    }
}
