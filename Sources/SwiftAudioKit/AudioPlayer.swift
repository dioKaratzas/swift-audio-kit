//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Observation

/// Observable, main-actor, and driven entirely by a synchronous state machine behind it.
@Observable
@MainActor
public final class AudioPlayer {
    /// What the player is doing right now, carrying the track it is doing it to.
    public private(set) var state = PlaybackState.idle

    /// The item's metadata with stream data filled into its gaps; `currentItem` keeps the
    /// metadata the caller supplied.
    public private(set) var metadata = AudioMetadata()

    /// Refreshed on `configuration.progressUpdateInterval`, and reset to zero on every track change.
    public private(set) var progress = PlaybackProgress.zero

    /// The rung actually in use, which the automatic policy may move without being asked.
    public private(set) var quality: AudioQuality

    /// `unknown` until the first path is reported, which still counts as usable.
    public private(set) var network = NetworkStatus.unknown

    /// What follows the current track in playback order, excluding the current track.
    public private(set) var upNext = [AudioItem]()

    /// The track `state` concerns, whose metadata is the caller's rather than the merged one.
    public var currentItem: AudioItem? {
        state.item
    }

    /// Every knob the player reads. Assigning a new value takes effect immediately, including
    /// the audio session policy.
    public var configuration: AudioPlayerConfiguration {
        get { machine.configuration }
        set {
            let previousSession = machine.configuration.audioSession
            machine.configuration = newValue
            engine.playheadInterval = newValue.progressUpdateInterval

            guard newValue.audioSession != previousSession else {
                return
            }
            Task { [session, policy = newValue.audioSession] in
                await session.update(policy: policy)
            }
        }
    }

    /// Swapped in for streams the default parser does not understand.
    public var metadataParser: any MetadataParser {
        get { machine.metadataParser }
        set { machine.metadataParser = newValue }
    }

    /// The player's own gain from `0` to `1`, independent of the system volume.
    public var volume: Float {
        didSet { engine.volume = volume }
    }

    /// A live stream plays at `1` whatever is set here, having no buffer to run ahead into.
    public var rate: Float {
        didSet { engine.defaultRate = rate }
    }

    /// Under `.one`, `next()` and `previous()` restart the current track rather than moving.
    public var repeatMode: RepeatMode {
        didSet { send(.setMode(PlaybackMode(repeatMode: repeatMode, isShuffled: isShuffled))) }
    }

    /// Toggling reshuffles only what has not played yet, keeping the current track in place.
    public var isShuffled: Bool {
        didSet { send(.setMode(PlaybackMode(repeatMode: repeatMode, isShuffled: isShuffled))) }
    }

    /// Tracks the queue steps over when advancing. Read on every move, so the set can change
    /// mid-playback, but the track already playing is left alone.
    public var skippedItems = Set<AudioItem.ID>() {
        didSet { send(.setSkipped(skippedItems)) }
    }

    /// Each access makes an independent stream, buffered to the newest 64 events: a consumer
    /// that falls behind loses the oldest rather than blocking the player.
    public var events: AsyncStream<AudioPlayerEvent> {
        broadcaster.makeStream()
    }

    @ObservationIgnored private var machine: PlaybackMachine
    @ObservationIgnored private let engine: any PlaybackEngine
    @ObservationIgnored private let scheduler: any PlaybackScheduler
    @ObservationIgnored private let broadcaster = EventBroadcaster()
    @ObservationIgnored private let session: AudioSessionController
    @ObservationIgnored private let background = BackgroundActivity()
    @ObservationIgnored private let networkMonitor = NetworkMonitor()
    @ObservationIgnored private var networkTask: Task<Void, Never>?
    @ObservationIgnored private let nowPlaying: NowPlayingController?
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private let interruptions = InterruptionObserver()
    @ObservationIgnored private var engineTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var qualityTask: Task<Void, Never>?

    /// Builds the AVFoundation engine and registers the given remote commands with the system.
    public convenience init(
        configuration: AudioPlayerConfiguration = .default,
        remoteCommands: Set<RemoteCommand> = .default
    ) {
        let engine = AVPlayerEngine()
        self.init(
            configuration: configuration,
            engine: engine,
            scheduler: SystemScheduler(),
            remoteCommands: remoteCommands,
            nowPlaying: NowPlayingController(session: NowPlayingSession(players: engine.nowPlayingPlayers))
        )
    }

    init(
        configuration: AudioPlayerConfiguration,
        engine: any PlaybackEngine,
        scheduler: any PlaybackScheduler,
        remoteCommands: Set<RemoteCommand> = [],
        nowPlaying: NowPlayingController? = nil
    ) {
        machine = PlaybackMachine(configuration: configuration)
        self.engine = engine
        self.scheduler = scheduler
        session = AudioSessionController(policy: configuration.audioSession)
        self.nowPlaying = nowPlaying
        quality = configuration.defaultQuality
        volume = engine.volume
        rate = engine.defaultRate
        engine.playheadInterval = configuration.progressUpdateInterval
        repeatMode = .off
        isShuffled = false

        observeEngine()
        observeNetwork()
        observeInterruptions()
        registerRemoteCommands(remoteCommands)
        scheduleQualityUpgrade()
    }

    isolated deinit {
        engineTask?.cancel()
        networkTask?.cancel()
        sessionTask?.cancel()
        nowPlaying?.unregisterAll()
        nowPlaying?.clear()
        retryTask?.cancel()
        connectionTask?.cancel()
        qualityTask?.cancel()
        broadcaster.finish()
        engine.unload()
    }

    // MARK: Transport

    /// Replaces the queue with this one track.
    public func play(_ item: AudioItem) {
        play([item])
    }

    /// Replaces the queue outright; an out-of-range index starts from the first playable track.
    public func play(_ items: [AudioItem], startingAt index: Int = 0) {
        send(.playItems(items, startingAt: index))
    }

    /// Resumes what is loaded, advances when nothing is, and reloads from scratch after a failure.
    public func play() {
        send(.play)
    }

    /// Records that the listener wants silence, so nothing resumes on its own afterwards.
    public func pause() {
        send(.pause)
    }

    /// Pauses only while sound is actually coming out, so a stall resolves towards playing.
    public func togglePlayPause() {
        state.isPlaying ? pause() : play()
    }

    /// Unloads the item and hands back the audio session, unlike `pause()`.
    public func stop() {
        send(.stop)
    }

    /// Steps over `skippedItems`, and emits `queueExhausted` rather than wrapping under `.off`.
    public func next() {
        send(.next)
    }

    /// Seeks to the start of the current track when there is nothing behind it.
    public func previous() {
        send(.previous)
    }

    /// `false` when nothing is loaded yet or the engine refuses the target.
    @discardableResult
    public func seek(to time: Duration, clampingToSeekableRange: Bool = true) async -> Bool {
        let target = clampingToSeekableRange ? progress.clampingToSeekableRange(time) : time
        let landed = await engine.seek(to: target, tolerance: .relaxed)
        if landed {
            send(.seeked(to: target))
        } else {
            Log.emit(.engine, .debug, "seek to \(target.totalSeconds)s was refused")
        }
        return landed
    }

    /// Relative to the playhead; a negative offset rewinds, and the result is clamped as usual.
    @discardableResult
    public func seek(by offset: Duration) async -> Bool {
        await seek(to: progress.elapsed + offset)
    }

    /// Jumps to the start of what can be seeked, which is the earliest point a live stream keeps.
    @discardableResult
    public func seekToStart(padding: Duration = .seconds(1)) async -> Bool {
        guard let seekable = progress.seekable else {
            return await seek(to: .zero, clampingToSeekableRange: false)
        }
        return await seek(to: seekable.lowerBound + padding)
    }

    /// Jumps to the newest point available, catching a live stream up to now. `false` when
    /// nothing is seekable yet, which is the case until the engine reports a range.
    @discardableResult
    public func seekToLiveEdge(padding: Duration = .seconds(1)) async -> Bool {
        guard let seekable = progress.seekable else {
            return false
        }
        return await seek(to: seekable.upperBound - padding)
    }

    // MARK: Queue

    /// Accounts for `skippedItems` and the repeat mode, so `.all` makes it always true.
    public var hasNext: Bool {
        machine.queue.hasNext(skipping: skippedItems)
    }

    /// False before playback starts, since there is no cursor to step back from.
    public var hasPrevious: Bool {
        machine.queue.hasPrevious(skipping: skippedItems)
    }

    /// Items already in the queue are ignored, matched by id.
    public func append(_ items: [AudioItem]) {
        send(.append(items))
    }

    /// Lands at the end of the playback order, and is ignored when the id is already queued.
    public func append(_ item: AudioItem) {
        append([item])
    }

    /// Queues a track to follow the one playing.
    public func insertNext(_ item: AudioItem) {
        send(.insertNext(item))
    }

    /// Removing the playing track starts whatever slides into its slot, or stops the player.
    public func remove(_ id: AudioItem.ID) {
        send(.remove(id))
    }

    /// `destination` is an index into the queue with the item already lifted out, which is one
    /// less than SwiftUI's `onMove` offset when moving a track later.
    public func move(from source: Int, to destination: Int) {
        send(.move(from: source, to: destination))
    }

    /// Empties the queue and stops, which also hands back the audio session.
    public func removeAll() {
        send(.removeAll)
    }

    /// Jumps straight to a queued track and plays it.
    public func play(_ id: AudioItem.ID) {
        send(.jump(id))
    }

    /// In the order they were added, which is not the playback order once shuffled.
    public var items: [AudioItem] {
        machine.queue.items
    }

    /// Position of the playing track within the playback order, or `nil` before one starts.
    public var currentIndex: Int? {
        machine.queue.currentIndex
    }

    /// Rewrites the system's now playing information from the current state.
    public func refreshNowPlayingInfo() {
        publish()
    }

    /// Reloads whatever is playing at the new quality and seeks back to where it was.
    public func setQuality(_ quality: AudioQuality) {
        send(.setQuality(quality))
    }

    // MARK: Wiring

    /// Takes the audio session up front, so a conflict with another app surfaces before
    /// playback rather than as a silent failure.
    public func prepareForPlayback() async throws(AudioPlayerError) {
        try await session.activate()
    }

    private func activateSession() {
        Task { [weak self, session] in
            do {
                try await session.activate()
            } catch let error as AudioPlayerError {
                Log.emit(.session, .error, "activation failed: \(error.logDescription)")
                self?.send(.sessionFailed(error))
            } catch {}
        }
    }

    private func observeInterruptions() {
        let signals = interruptions.signals()
        sessionTask = Task { [weak self] in
            for await signal in signals {
                switch signal {
                case let .becameInactive(reason):
                    self?.send(.interrupted(reason))
                case let .resumptionRecommended(shouldResume):
                    self?.send(.interruptionEnded(shouldResume: shouldResume))
                }
            }
        }
    }

    private func registerRemoteCommands(_ commands: Set<RemoteCommand>) {
        guard !commands.isEmpty, nowPlaying != nil else {
            return
        }
        nowPlaying?.register(commands) { [weak self] command, position in
            self?.handle(command, position: position)
        }
    }

    private func handle(_ command: RemoteCommand, position: Duration?) {
        Log.emit(.nowPlaying, .debug, "remote command \(command)")

        switch command {
        case .play: play()
        case .pause: pause()
        case .togglePlayPause: togglePlayPause()
        case .stop: stop()
        case .nextTrack: next()
        case .previousTrack: previous()
        case .skipForward: Task { await seek(by: .seconds(15)) }
        case .skipBackward: Task { await seek(by: .seconds(-15)) }
        case .changePlaybackPosition:
            guard let position else {
                return
            }
            Task { await seek(to: position) }
        }
    }

    private func observeNetwork() {
        networkTask = Task { [weak self, networkMonitor] in
            for await status in await networkMonitor.statuses() {
                self?.send(.network(status))
            }
        }
    }

    private func observeEngine() {
        let signals = engine.signals
        engineTask = Task { [weak self] in
            for await signal in signals {
                self?.send(.engine(signal))
            }
        }
    }

    private func send(_ signal: Signal) {
        let previous = machine.state
        perform(machine.handle(signal))
        if machine.state != previous {
            Log.emit(.player, .notice, "state \(previous.logDescription) → \(self.machine.state.logDescription)")
        }
        publish()
    }

    private func publish() {
        state = machine.state
        metadata = machine.metadata
        progress = machine.progress
        quality = machine.quality
        network = machine.network
        upNext = machine.queue.upNext

        guard machine.configuration.updatesNowPlayingInfo else {
            return
        }
        nowPlaying?.update(
            item: machine.state.item,
            metadata: machine.metadata,
            progress: machine.progress,
            isPlaying: machine.state.isPlaying
        )
    }

    private func perform(_ effects: [Effect]) {
        for effect in effects {
            perform(effect)
        }
    }

    private func perform(_ effect: Effect) {
        Log.record(effect)

        switch effect {
        case let .load(request, generation):
            load(request, generation: generation)
        case .unload:
            engine.unload()
        case .play:
            engine.play()
        case .pause:
            engine.pause()
        case let .seek(time, generation):
            seek(to: time, generation: generation)
        case let .scheduleRetry(after, generation):
            retryTask = schedule(after: after) { .retryDue(generation: generation) }
        case .cancelRetry:
            retryTask?.cancel()
        case let .startConnectionLossTimer(deadline, generation):
            connectionTask = schedule(after: deadline) { .connectionLossDeadlineReached(generation: generation) }
        case .cancelConnectionLossTimer:
            connectionTask?.cancel()
        case let .scheduleQualityUpgrade(after):
            qualityTask = schedule(after: after) { .qualityUpgradeDue }
        case let .emit(event):
            Log.record(event)
            broadcaster.emit(event)
        case .activateSession:
            activateSession()
        case .deactivateSession:
            Task { [session] in try? await session.deactivate() }
        case .beginBackgroundActivity:
            background.begin()
        case .endBackgroundActivity:
            background.end()
        }
    }

    private func load(_ request: PlaybackRequest, generation: Int) {
        Task { [weak self] in
            await self?.engine.load(request)
            self?.discardIfStale(generation)
        }
    }

    private func seek(to time: Duration, generation: Int) {
        Task { [weak self] in
            guard let self else {
                return
            }
            let landed = await engine.seek(to: time, tolerance: .relaxed)
            guard generation == machine.generation else {
                return
            }
            if landed {
                send(.seeked(to: time))
            }
        }
    }

    /// Results for a track the listener has already left are dropped rather than applied.
    private func discardIfStale(_ generation: Int) {
        guard generation == machine.generation else {
            Log.emit(.engine, .debug, "discarded result for generation \(generation), now \(self.machine.generation)")
            return
        }
        publish()
    }

    private func schedule(after delay: Duration, signal: @escaping @Sendable () -> Signal) -> Task<Void, Never> {
        Task { [weak self, scheduler] in
            guard await (try? scheduler.sleep(for: delay)) != nil else {
                return
            }
            self?.send(signal())
        }
    }

    private func scheduleQualityUpgrade() {
        guard let interval = machine.configuration.quality.interval else {
            return
        }
        qualityTask = schedule(after: interval) { .qualityUpgradeDue }
    }
}
