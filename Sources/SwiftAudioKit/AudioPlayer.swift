//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Observation

@Observable
@MainActor
public final class AudioPlayer {
    public private(set) var state = PlaybackState.idle
    public private(set) var metadata = AudioMetadata()
    public private(set) var progress = PlaybackProgress.zero
    public private(set) var quality: AudioQuality
    public private(set) var network = NetworkStatus.unknown
    public private(set) var upNext = [AudioItem]()

    public var currentItem: AudioItem? {
        state.item
    }

    public var configuration: AudioPlayerConfiguration {
        get { machine.configuration }
        set { machine.configuration = newValue }
    }

    public var metadataParser: any MetadataParser {
        get { machine.metadataParser }
        set { machine.metadataParser = newValue }
    }

    public var volume: Float {
        didSet { engine.volume = volume }
    }

    public var rate: Float {
        didSet { engine.defaultRate = rate }
    }

    public var repeatMode: RepeatMode {
        didSet { send(.setMode(PlaybackMode(repeatMode: repeatMode, isShuffled: isShuffled))) }
    }

    public var isShuffled: Bool {
        didSet { send(.setMode(PlaybackMode(repeatMode: repeatMode, isShuffled: isShuffled))) }
    }

    /// Tracks the queue steps over when advancing.
    public var skippedItems = Set<AudioItem.ID>() {
        didSet { send(.setSkipped(skippedItems)) }
    }

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
    @ObservationIgnored private var engineTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var qualityTask: Task<Void, Never>?

    public convenience init(configuration: AudioPlayerConfiguration = .default) {
        self.init(configuration: configuration, engine: AVPlayerEngine(), scheduler: SystemScheduler())
    }

    init(
        configuration: AudioPlayerConfiguration,
        engine: any PlaybackEngine,
        scheduler: any PlaybackScheduler
    ) {
        machine = PlaybackMachine(configuration: configuration)
        self.engine = engine
        self.scheduler = scheduler
        session = AudioSessionController(policy: configuration.audioSession)
        quality = configuration.defaultQuality
        volume = engine.volume
        rate = engine.defaultRate
        repeatMode = .off
        isShuffled = false

        observeEngine()
        observeNetwork()
        scheduleQualityUpgrade()
    }

    isolated deinit {
        engineTask?.cancel()
        networkTask?.cancel()
        retryTask?.cancel()
        connectionTask?.cancel()
        qualityTask?.cancel()
        broadcaster.finish()
        engine.unload()
    }

    // MARK: Transport

    public func play(_ item: AudioItem) {
        play([item])
    }

    public func play(_ items: [AudioItem], startingAt index: Int = 0) {
        send(.playItems(items, startingAt: index))
    }

    public func play() {
        send(.play)
    }

    public func pause() {
        send(.pause)
    }

    public func togglePlayPause() {
        state.isPlaying ? pause() : play()
    }

    public func stop() {
        send(.stop)
    }

    public func next() {
        send(.next)
    }

    public func previous() {
        send(.previous)
    }

    @discardableResult
    public func seek(to time: Duration, clampingToSeekableRange: Bool = true) async -> Bool {
        let target = clampingToSeekableRange ? progress.clampingToSeekableRange(time) : time
        return await engine.seek(to: target, tolerance: .relaxed)
    }

    @discardableResult
    public func seek(by offset: Duration) async -> Bool {
        await seek(to: progress.elapsed + offset)
    }

    // MARK: Queue

    public var hasNext: Bool {
        machine.queue.hasNext(skipping: skippedItems)
    }

    public var hasPrevious: Bool {
        machine.queue.hasPrevious(skipping: skippedItems)
    }

    public func append(_ items: [AudioItem]) {
        send(.append(items))
    }

    public func append(_ item: AudioItem) {
        append([item])
    }

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
                self?.send(.sessionFailed(error))
            } catch {}
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
        perform(machine.handle(signal))
        publish()
    }

    private func publish() {
        state = machine.state
        metadata = machine.metadata
        progress = machine.progress
        quality = machine.quality
        network = machine.network
        upNext = machine.queue.upNext
    }

    private func perform(_ effects: [Effect]) {
        for effect in effects {
            perform(effect)
        }
    }

    private func perform(_ effect: Effect) {
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
            await engine.seek(to: time, tolerance: .relaxed)
            discardIfStale(generation)
        }
    }

    /// Results for a track the listener has already left are dropped rather than applied.
    private func discardIfStale(_ generation: Int) {
        guard generation == machine.generation else {
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
