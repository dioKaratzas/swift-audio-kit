//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import AVFoundation

@MainActor
final class AVPlayerEngine: PlaybackEngine {
    let signals: AsyncStream<EngineSignal>

    private let continuation: AsyncStream<EngineSignal>.Continuation
    private let player = AVPlayer()
    private var playerObservations = [NSKeyValueObservation]()
    private var itemObservations = [NSKeyValueObservation]()
    private var notifications = [any NSObjectProtocol]()
    private var playheadToken: Any?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var metadataForwarder: MetadataForwarder?

    private(set) var progress = PlaybackProgress.zero
    private(set) var timeControl = EngineTimeControl.paused
    private(set) var supportsAudioProcessing = false

    #if canImport(MediaToolbox) && !os(watchOS)
        private let effects = AudioEffectChain()
    #endif

    var nowPlayingPlayers: [AVPlayer] {
        [player]
    }

    var playheadInterval = Duration.seconds(1)

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    var defaultRate: Float {
        get { player.defaultRate }
        set {
            player.defaultRate = newValue
            // `defaultRate` only takes effect on the next `play()`, so a change made while
            // playing has to be applied to the current rate as well.
            if player.timeControlStatus == .playing {
                player.rate = newValue
            }
        }
    }

    init() {
        (signals, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(64))
        #if !os(watchOS) && !os(visionOS)
            player.allowsExternalPlayback = false
        #endif
        observePlayer()
    }

    deinit {
        continuation.finish()
    }

    func load(_ request: PlaybackRequest) async {
        unloadItem()
        continuation.yield(.statusChanged(.loading))

        let item = AVPlayerItem(asset: AVURLAsset(url: request.url, options: request.assetOptions))
        if let buffer = request.preferredForwardBufferDuration {
            item.preferredForwardBufferDuration = buffer.totalSeconds
        }
        if let bitRate = request.preferredPeakBitRate {
            item.preferredPeakBitRate = bitRate
        }

        observe(item)
        await attachEffects(to: item, request: request)
        player.replaceCurrentItem(with: item)
        observePlayhead()

        if let startTime = request.startTime {
            await seek(to: startTime, tolerance: .relaxed)
        }
    }

    func unload() {
        unloadItem()
        supportsAudioProcessing = false
        continuation.yield(.statusChanged(.idle))
    }

    #if !os(watchOS)
        func setAudioUnits(_ units: [AVAudioUnit]) {
            #if canImport(MediaToolbox)
                effects.setUnits(units)
            #endif
        }
    #endif

    /// A live stream and an HLS playlist expose no audio track, so before the release that can
    /// tap the mix of all tracks there is nothing to attach a processor to.
    private func attachEffects(to item: AVPlayerItem, request: PlaybackRequest) async {
        #if canImport(MediaToolbox) && !os(watchOS)
            guard request.supportsAudioProcessing,
                  let mix = await AudioProcessingTap.makeAudioMix(for: item.asset, chain: effects) else {
                supportsAudioProcessing = false
                return
            }
            item.audioMix = mix
            supportsAudioProcessing = true
        #else
            supportsAudioProcessing = false
        #endif
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    @discardableResult
    func seek(to time: Duration, tolerance: SeekTolerance) async -> Bool {
        guard let item = player.currentItem else {
            return false
        }
        return await item.seek(
            to: CMTime(duration: time),
            toleranceBefore: tolerance.before.map(CMTime.init(duration:)) ?? .positiveInfinity,
            toleranceAfter: tolerance.after.map(CMTime.init(duration:)) ?? .positiveInfinity
        )
    }

    // MARK: Observation

    private func observePlayer() {
        let continuation = continuation

        playerObservations = [
            player.observe(\.timeControlStatus, options: [.initial, .new]) { player, _ in
                continuation.yield(.timeControlChanged(player.engineTimeControl))
            }
        ]
    }

    private func observe(_ item: AVPlayerItem) {
        let continuation = continuation

        itemObservations = [
            item.observe(\.status, options: [.new]) { item, _ in
                switch item.status {
                case .readyToPlay:
                    continuation.yield(.statusChanged(.ready))
                case .failed:
                    let failure = PlaybackFailure(item.error ?? URLError(.unknown))
                    Log.emit(.engine, .error, "item failed: \(failure.domain) \(failure.code)")
                    continuation.yield(.statusChanged(.failed(failure)))
                    continuation.yield(.failed(failure))
                default:
                    break
                }
            },
            item.observe(\.duration, options: [.new]) { item, _ in
                guard let duration = item.duration.duration else {
                    return
                }
                continuation.yield(.durationResolved(duration))
            },
            item.observe(\.loadedTimeRanges, options: [.new]) { item, _ in
                continuation.yield(.bufferChanged(loaded: item.loadedRange, seekable: item.seekableRange))
            },
            item.observe(\.seekableTimeRanges, options: [.new]) { item, _ in
                continuation.yield(.bufferChanged(loaded: item.loadedRange, seekable: item.seekableRange))
            }
        ]

        observeNotifications(for: item)
        observeMetadata(on: item)
    }

    private func observeNotifications(for item: AVPlayerItem) {
        let continuation = continuation
        let center = NotificationCenter.default

        notifications = [
            center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
                continuation.yield(.reachedEnd)
            },
            center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { note in
                let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? any Error
                continuation.yield(.failed(PlaybackFailure(error ?? URLError(.unknown))))
            },
            center.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: item, queue: .main) { note in
                guard let entry = (note.object as? AVPlayerItem)?.errorLog()?.events.last else {
                    return
                }
                continuation.yield(.errorLogged(PlaybackFailure(
                    domain: entry.errorDomain,
                    code: entry.errorStatusCode,
                    message: entry.errorComment ?? ""
                )))
            }
        ]
    }

    private func observeMetadata(on item: AVPlayerItem) {
        let forwarder = MetadataForwarder(continuation: continuation)
        let output = AVPlayerItemMetadataOutput()
        output.setDelegate(forwarder, queue: .main)
        item.add(output)

        metadataForwarder = forwarder
        metadataOutput = output
    }

    private func observePlayhead() {
        removePlayheadObserver()
        let continuation = continuation
        let interval = CMTime(duration: playheadInterval)

        playheadToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard let elapsed = time.duration else {
                return
            }
            continuation.yield(.playheadMoved(elapsed))
        }
    }

    // MARK: Teardown

    private func unloadItem() {
        if let item = player.currentItem, let metadataOutput {
            item.remove(metadataOutput)
        }
        metadataOutput = nil
        metadataForwarder = nil

        removePlayheadObserver()
        notifications.forEach(NotificationCenter.default.removeObserver)
        notifications.removeAll()
        itemObservations.removeAll()

        player.replaceCurrentItem(with: nil)
        progress = .zero
    }

    private func removePlayheadObserver() {
        guard let playheadToken else {
            return
        }
        player.removeTimeObserver(playheadToken)
        self.playheadToken = nil
    }
}

private final class MetadataForwarder: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    private let continuation: AsyncStream<EngineSignal>.Continuation

    init(continuation: AsyncStream<EngineSignal>.Continuation) {
        self.continuation = continuation
    }

    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        // The groups are declared NS_SWIFT_SENDING, so AVFoundation hands them over and does
        // not touch them again, but region analysis cannot see that through the witness.
        nonisolated(unsafe) let items = groups.flatMap(\.items)
        guard !items.isEmpty else {
            return
        }

        Task { [continuation] in
            var entries = [MetadataEntry]()
            for item in items {
                await entries.append(MetadataEntry(item))
            }
            continuation.yield(.metadataReceived(entries))
        }
    }
}

private extension AVPlayer {
    nonisolated var engineTimeControl: EngineTimeControl {
        switch timeControlStatus {
        case .paused:
            .paused
        case .playing:
            .playing
        case .waitingToPlayAtSpecifiedRate:
            .waiting(reason: reasonForWaitingToPlay.map(EngineTimeControl.WaitingReason.init))
        @unknown default:
            .paused
        }
    }
}

private extension AVPlayerItem {
    nonisolated var loadedRange: ClosedRange<Duration>? {
        loadedTimeRanges.last?.timeRangeValue.durationRange
    }

    nonisolated var seekableRange: ClosedRange<Duration>? {
        seekableTimeRanges.last?.timeRangeValue.durationRange
    }
}

private extension EngineTimeControl.WaitingReason {
    init(_ reason: AVPlayer.WaitingReason) {
        switch reason {
        case .evaluatingBufferingRate: self = .evaluatingBufferingRate
        case .toMinimizeStalls: self = .minimizingStalls
        case .noItemToPlay: self = .noItemToPlay
        default: self = .minimizingStalls
        }
    }
}

private extension MetadataEntry {
    init(_ item: AVMetadataItem) async {
        let values = try? await item.load(.stringValue, .numberValue, .dataValue)
        self.init(
            commonKey: item.commonKey?.rawValue,
            identifier: item.identifier?.rawValue,
            stringValue: values?.0,
            numberValue: values?.1?.doubleValue,
            dataValue: values?.2
        )
    }
}

private extension PlaybackRequest {
    var assetOptions: [String: Any] {
        var options = [String: Any]()
        if let overrideMIMEType {
            options[AVURLAssetOverrideMIMETypeKey] = overrideMIMEType
        }
        if let httpUserAgent {
            options[AVURLAssetHTTPUserAgentKey] = httpUserAgent
        }
        return options
    }
}
