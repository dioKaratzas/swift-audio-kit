//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Observation

/// A queue-driven audio player built on `AVPlayer`.
///
/// Hand it tracks and it does the rest: resolving the right stream for the current
/// ``quality``, retrying failed loads, waiting out connection losses, reacting to audio
/// session interruptions, and keeping the system's Now Playing information and remote
/// commands in step.
///
///     let player = AudioPlayer(configuration: .podcast)
///     player.play([
///         AudioItem(url: firstURL, metadata: AudioMetadata(title: "Episode 1")),
///         AudioItem(url: secondURL, metadata: AudioMetadata(title: "Episode 2"))
///     ])
///
/// The player is `@Observable`, so reading ``state``, ``progress``, ``metadata``, ``quality``,
/// ``network`` or ``upNext`` from a SwiftUI `body` is enough to keep that view current. There
/// is no delegate to implement. Point-in-time notifications that leave no trace in the state —
/// a track finishing, the queue running out, a recovered error — arrive as
/// ``AudioPlayerEvent`` values on ``events``.
///
/// Behaviour comes from ``AudioPlayerConfiguration``, which can be replaced at any time,
/// including mid-track.
///
/// - Important: The whole type is `@MainActor`. Create it and call into it from the main
///   actor, which is where a UI reads it anyway; the work that takes time happens in child
///   tasks and only the resulting state change is applied back.
/// - Note: A player holds the audio session for as long as ``PlaybackState/isActive`` is
///   `true`. Call ``stop()`` rather than ``pause()`` when you want other apps to get their
///   turn.
@Observable
@MainActor
public final class AudioPlayer {
    /// What the player is doing right now, carrying the track it is doing it to.
    ///
    /// Observable. Every case but ``PlaybackState/idle`` carries its ``AudioItem``, so a view
    /// can read the track and the phase from this one value.
    public private(set) var state = PlaybackState.idle

    /// The current track's metadata, with anything the stream announced filled into its gaps.
    ///
    /// Observable. Values you supplied on the ``AudioItem`` outrank the stream's; only fields
    /// left `nil` are filled. ``currentItem`` keeps your metadata unmerged, so use this for
    /// display and that for round-tripping what you supplied.
    public private(set) var metadata = AudioMetadata()

    /// Where the playhead is and what surrounds it.
    ///
    /// Observable. Refreshed every ``AudioPlayerConfiguration/progressUpdateInterval``, and
    /// reset to ``PlaybackProgress/zero`` on every track change.
    ///
    /// - Note: ``PlaybackProgress/duration`` and ``PlaybackProgress/fraction`` are `nil` for a
    ///   live stream, which has no end to measure against. That is not an error.
    public private(set) var progress = PlaybackProgress.zero

    /// The quality rung actually in use.
    ///
    /// Observable. Starts at ``AudioPlayerConfiguration/defaultQuality``, and under
    /// ``QualityPolicy/automatic(interval:downgradeAfterInterruptions:)`` the player moves it
    /// without being asked. Every change emits ``AudioPlayerEvent/qualityChanged(from:to:)``.
    ///
    /// - Note: This is the rung requested, which an item need not offer. The stream actually
    ///   chosen comes from ``AudioSources/resolve(preferring:)``.
    public private(set) var quality: AudioQuality

    /// What the current network path affords.
    ///
    /// Observable. ``NetworkStatus/unknown`` until the first path is reported, which still
    /// counts as usable — see ``NetworkStatus/isUsable``.
    public private(set) var network = NetworkStatus.unknown

    /// What follows the current track in playback order, excluding the current track.
    ///
    /// Observable. Shows the shuffled order when ``isShuffled`` is on, and includes tracks
    /// listed in ``skippedItems``, which the player will pass over rather than remove.
    public private(set) var upNext = [AudioItem]()

    #if canImport(AVFAudio) && !os(watchOS)
        /// The audio units playback is rendered through.
        ///
        /// Empty by default, which routes audio straight through. Assign any `AVAudioUnit` —
        /// an equalizer, a reverb, a compressor, an AUv3 of your own — and keep your own
        /// reference to change its parameters while it plays. See ``AudioProcessing``.
        public let audioProcessing = AudioProcessing()
    #endif

    /// The track ``state`` concerns, or `nil` when nothing is loaded.
    ///
    /// Carries the metadata you supplied rather than the merged metadata published on
    /// ``metadata``, so it round-trips what you put in.
    public var currentItem: AudioItem? {
        state.item
    }

    /// Every knob the player reads.
    ///
    /// Assigning a new value takes effect immediately rather than at the next track, the audio
    /// session policy included. Mutate a copy and assign it back; there is no way to change one
    /// knob in place.
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

    /// The parser that turns a stream's timed metadata into ``AudioMetadata``.
    ///
    /// Defaults to ``DefaultMetadataParser``. Swap in your own for streams it does not
    /// understand; the change applies from the next burst.
    ///
    /// - Warning: The parser is invoked synchronously on the main actor, once per burst. Do no
    ///   blocking work in it.
    public var metadataParser: any MetadataParser {
        get { machine.metadataParser }
        set { machine.metadataParser = newValue }
    }

    /// The player's own gain, from `0` to `1`.
    ///
    /// Maps to the underlying `AVPlayer`'s volume, which is independent of the system volume
    /// and applied on top of it. Changing it takes effect immediately.
    public var volume: Float {
        didSet { engine.volume = volume }
    }

    /// How fast playback runs, where `1` is normal speed.
    ///
    /// Sets the rate the engine starts each track at, and is also applied to the track already
    /// playing, so a change is audible immediately rather than at the next item.
    ///
    /// - Important: A live stream plays at `1` whatever is set here, because it has no buffer
    ///   to run ahead into. Rate control is only meaningful for on-demand audio.
    public var rate: Float {
        didSet { engine.defaultRate = rate }
    }

    /// What the queue does when it runs off either end.
    ///
    /// - Important: Under ``RepeatMode/one``, ``next()`` and ``previous()`` restart the current
    ///   track rather than moving to another one.
    public var repeatMode: RepeatMode {
        didSet { send(.setMode(PlaybackMode(repeatMode: repeatMode, isShuffled: isShuffled))) }
    }

    /// Whether playback order is shuffled away from the order tracks were added in.
    ///
    /// Toggling reshuffles only what has not played yet and keeps the current track in place,
    /// so the track playing does not change under the listener.
    public var isShuffled: Bool {
        didSet { send(.setMode(PlaybackMode(repeatMode: repeatMode, isShuffled: isShuffled))) }
    }

    /// Identifiers of tracks the queue steps over when advancing.
    ///
    /// Read on every move, so the set can change mid-playback. Skipped tracks stay in the queue
    /// and in ``upNext``; they are passed over, not removed.
    ///
    /// - Note: Adding the track that is already playing does not stop it. The set governs where
    ///   the cursor may move next, not what is loaded now.
    public var skippedItems = Set<AudioItem.ID>() {
        didSet { send(.setSkipped(skippedItems)) }
    }

    /// A stream of point-in-time notifications about what the player did.
    ///
    /// Use this for things that leave no trace in the observable state — a track finishing, the
    /// queue running out, an error the engine recovered from. Read ``state`` and the other
    /// observable properties for what is true now.
    ///
    ///     .task {
    ///         for await event in player.events {
    ///             if case .queueExhausted = event { loadMoreEpisodes() }
    ///         }
    ///     }
    ///
    /// - Important: Every access creates a **new, independent** stream with its own
    ///   continuation, so several observers can consume events without starving one another.
    ///   Store the stream if you intend to iterate it more than once; reading the property
    ///   twice gives you two unrelated streams.
    /// - Note: Each stream buffers the 64 newest events. A consumer that falls behind loses the
    ///   oldest rather than applying backpressure to playback. Streams finish when the player is
    ///   deinitialised, which ends the `for await` loop.
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

    /// Creates a player backed by AVFoundation.
    ///
    /// Builds the `AVPlayer`-based engine, starts watching the network path and audio session
    /// interruptions, and registers the requested remote commands with the system.
    ///
    /// - Parameters:
    ///   - configuration: Every knob the player reads. Defaults to
    ///     ``AudioPlayerConfiguration/default``, which suits music.
    ///     ``AudioPlayerConfiguration/podcast`` and ``AudioPlayerConfiguration/liveRadio`` are
    ///     presets for the other two common shapes.
    ///   - remoteCommands: The lock screen and Control Center controls to register. Defaults to
    ///     transport plus scrubbing. Pass an empty set to register none, and
    ///     ``Swift/Set/transport`` for a live stream with nothing to scrub.
    ///
    /// - Note: Creating a player does not touch the audio session. Call
    ///   ``prepareForPlayback()`` if you want a conflict to surface before the first track.
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

        #if canImport(AVFAudio) && !os(watchOS)
            audioProcessing.onChange = { [weak engine] units in
                engine?.setAudioUnits(units)
            }
        #endif

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

    /// Replaces the queue with a single track and starts playing it.
    ///
    /// Equivalent to passing a one-element array to ``play(_:startingAt:)``. Anything already
    /// queued is discarded.
    ///
    ///     player.play(AudioItem(url: trackURL))
    ///
    /// - Parameter item: The track to play.
    public func play(_ item: AudioItem) {
        play([item])
    }

    /// Replaces the queue and starts playing from a given position.
    ///
    /// Discards whatever was queued, including the track currently playing.
    ///
    /// - Parameters:
    ///   - items: The tracks to queue, in the order they were added. An empty array fails the
    ///     player with ``AudioPlayerError/noPlayableItems``.
    ///   - index: Where in `items` to start. Defaults to `0`. An index outside the array is not
    ///     an error: the player advances to the first playable track instead, honouring
    ///     ``skippedItems``.
    ///
    /// - Note: The index addresses `items`, so it means what you expect even when ``isShuffled``
    ///   is on. Playback continues from there in shuffled order.
    public func play(_ items: [AudioItem], startingAt index: Int = 0) {
        send(.playItems(items, startingAt: index))
    }

    /// Starts or resumes playback.
    ///
    /// Resumes what is loaded, advances to the next track when nothing is, and reloads the item
    /// from scratch after a failure. Records that the listener wants sound, so a later stall
    /// resolves back towards playing on its own.
    public func play() {
        send(.play)
    }

    /// Pauses playback, keeping the item loaded and the audio session active.
    ///
    /// - Important: This records that the *listener* wants silence, so nothing resumes on its
    ///   own afterwards — not an interruption ending, not a connection returning. Only another
    ///   ``play()`` starts sound again. Use ``stop()`` to also unload and release the session.
    public func pause() {
        send(.pause)
    }

    /// Pauses when sound is coming out, and plays otherwise.
    ///
    /// - Note: The decision is made on ``PlaybackState/isPlaying``, not on intent, so tapping
    ///   during a stall resolves towards playing rather than pausing.
    public func togglePlayPause() {
        state.isPlaying ? pause() : play()
    }

    /// Stops playback, unloads the item, and hands back the audio session.
    ///
    /// Leaves the player ``PlaybackState/idle`` with the queue intact. Unlike ``pause()``, this
    /// releases the audio session so another app can take it.
    public func stop() {
        send(.stop)
    }

    /// Advances to the next playable track.
    ///
    /// Steps over anything in ``skippedItems``, and wraps to the front under
    /// ``RepeatMode/all``. Under ``RepeatMode/off``, running off the end emits
    /// ``AudioPlayerEvent/queueExhausted`` and stops the player.
    ///
    /// - Important: Under ``RepeatMode/one`` this restarts the current track rather than moving.
    public func next() {
        send(.next)
    }

    /// Goes back to the previous playable track.
    ///
    /// Seeks to the start of the current track when there is nothing behind it, which is the
    /// behaviour a listener expects from a back button. Wraps to the end under
    /// ``RepeatMode/all``.
    ///
    /// - Important: Under ``RepeatMode/one`` this restarts the current track rather than moving.
    public func previous() {
        send(.previous)
    }

    /// Moves the playhead to an absolute time.
    ///
    /// - Parameters:
    ///   - time: Where to move the playhead, measured from the start of the stream rather than
    ///     from the start of the seekable range.
    ///   - clampingToSeekableRange: Whether to pull `time` inside the seekable window first,
    ///     keeping a second's padding from each edge. Defaults to `true`, because the exact
    ///     edges are not reliably seekable. Pass `false` to send the time through untouched and
    ///     let the engine refuse it.
    /// - Returns: `true` when the playhead landed. `false` when nothing is loaded yet, or when
    ///   the engine refused the target — an unbuffered region of a live stream, or a time past
    ///   the end.
    ///
    /// - Note: The seek is approximate: it lands on the nearest sync sample rather than exactly
    ///   on `time`, which is what makes scrubbing feel immediate.
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

    /// Moves the playhead by an offset relative to where it is now.
    ///
    /// - Parameter offset: How far to move. A negative value rewinds. The resulting time is
    ///   clamped into the seekable range, as with ``seek(to:clampingToSeekableRange:)``.
    /// - Returns: `true` when the playhead landed; `false` when nothing is loaded or the engine
    ///   refused the target.
    @discardableResult
    public func seek(by offset: Duration) async -> Bool {
        await seek(to: progress.elapsed + offset)
    }

    /// Moves the playhead to the earliest point that can be seeked to.
    ///
    /// The start of the file for an on-demand track, and the oldest moment a live stream still
    /// retains for a broadcast.
    ///
    /// - Parameter padding: How far inside the start of the seekable range to land. Defaults to
    ///   one second, because the exact edge is not reliably seekable.
    /// - Returns: `true` when the playhead landed. `false` when nothing is loaded or the engine
    ///   refused the target. When no seekable range has been reported yet this seeks to `.zero`
    ///   instead of failing.
    @discardableResult
    public func seekToStart(padding: Duration = .seconds(1)) async -> Bool {
        guard let seekable = progress.seekable else {
            return await seek(to: .zero, clampingToSeekableRange: false)
        }
        return await seek(to: seekable.lowerBound + padding)
    }

    /// Moves the playhead to the newest point available, catching a live stream up to now.
    ///
    /// - Parameter padding: How far inside the end of the seekable range to land. Defaults to
    ///   one second, because the exact edge is not reliably seekable.
    /// - Returns: `true` when the playhead landed. `false` when there is **no seekable range at
    ///   all**, which is the case until the engine reports one — so a `false` here often means
    ///   "too early to tell" rather than "the seek failed". Also `false` when the engine refused
    ///   the target.
    @discardableResult
    public func seekToLiveEdge(padding: Duration = .seconds(1)) async -> Bool {
        guard let seekable = progress.seekable else {
            return false
        }
        return await seek(to: seekable.upperBound - padding)
    }

    // MARK: Queue

    /// Whether ``next()`` would move to another track.
    ///
    /// Accounts for ``skippedItems`` and ``repeatMode``, so ``RepeatMode/all`` makes it always
    /// `true` while anything is queued.
    public var hasNext: Bool {
        machine.queue.hasNext(skipping: skippedItems)
    }

    /// Whether ``previous()`` would move to another track.
    ///
    /// Always `false` before playback starts, since there is no cursor to step back from.
    ///
    /// - Note: A `false` here does not make ``previous()`` a no-op: with a track loaded it seeks
    ///   to the start of that track instead.
    public var hasPrevious: Bool {
        machine.queue.hasPrevious(skipping: skippedItems)
    }

    /// Adds tracks to the end of the queue.
    ///
    /// - Parameter items: The tracks to add. Any whose ``AudioItem/id`` is already queued are
    ///   ignored, so appending the same batch twice is a no-op rather than a duplication. Give
    ///   each copy its own identifier to queue the same URL more than once.
    public func append(_ items: [AudioItem]) {
        send(.append(items))
    }

    /// Adds one track to the end of the queue.
    ///
    /// - Parameter item: The track to add. Lands at the end of the playback order, and is
    ///   ignored when its ``AudioItem/id`` is already queued.
    public func append(_ item: AudioItem) {
        append([item])
    }

    /// Queues a track to play immediately after the current one.
    ///
    /// - Parameter item: The track to queue next. Lands at the front when nothing is playing,
    ///   and is ignored when its ``AudioItem/id`` is already queued.
    public func insertNext(_ item: AudioItem) {
        send(.insertNext(item))
    }

    /// Removes a track from the queue.
    ///
    /// - Parameter id: The ``AudioItem/id`` of the track to remove. An identifier that is not
    ///   queued is ignored.
    ///
    /// - Important: Removing the track that is playing immediately starts whatever slides into
    ///   its slot, and stops the player when nothing does.
    public func remove(_ id: AudioItem.ID) {
        send(.remove(id))
    }

    /// Moves a track within the playback order.
    ///
    /// - Parameters:
    ///   - source: The index in the playback order to lift the track out of.
    ///   - destination: The index to insert it at, in the order **with the track already lifted
    ///     out**.
    ///
    /// - Important: The destination convention differs from SwiftUI's `onMove`, whose offset is
    ///   one greater when moving an item later in the list. Subtract one from that offset before
    ///   calling, or the track lands a position short.
    /// - Note: Does nothing when either index is out of bounds, or when the two are equal. The
    ///   cursor follows the track, so moving what is playing does not interrupt it.
    public func move(from source: Int, to destination: Int) {
        send(.move(from: source, to: destination))
    }

    /// Empties the queue and stops playback.
    ///
    /// Also unloads the item and hands back the audio session, exactly as ``stop()`` does.
    public func removeAll() {
        send(.removeAll)
    }

    /// Jumps straight to a queued track and plays it.
    ///
    /// - Parameter id: The ``AudioItem/id`` of the track to play. An identifier that is not
    ///   queued is ignored, leaving playback untouched.
    ///
    /// - Note: A jump is an explicit instruction, so it ignores ``skippedItems`` and
    ///   ``repeatMode`` and goes where it is told.
    public func play(_ id: AudioItem.ID) {
        send(.jump(id))
    }

    /// Every queued track, in the order it was added.
    ///
    /// - Note: Not the playback order once ``isShuffled`` is on. Read ``upNext`` for what plays
    ///   next.
    public var items: [AudioItem] {
        machine.queue.items
    }

    /// Position of the playing track within the playback order.
    ///
    /// `nil` before anything starts. Indexes the playback order rather than ``items``, so with
    /// shuffle on it is not a position in the list you supplied.
    public var currentIndex: Int? {
        machine.queue.currentIndex
    }

    /// Rewrites the system's Now Playing information from the current state.
    ///
    /// The player does this on its own whenever the state changes, so call it only after
    /// something outside the player has overwritten the shared `MPNowPlayingInfoCenter`.
    ///
    /// - Note: Publishes nothing while ``AudioPlayerConfiguration/publishesNowPlayingInfo`` is
    ///   `false`, since the player owns no Now Playing information to restore.
    public func refreshNowPlayingInfo() {
        publish()
    }

    /// Changes the quality rung, reloading the current track at the new one.
    ///
    /// The track is reloaded from the new stream and seeked back to where it was, so playback
    /// resumes near the same point after a short rebuffer.
    ///
    /// - Parameter quality: The rung to move to. Setting the rung already in use does nothing.
    ///   An item that offers nothing at this rung falls back to its nearest stream; see
    ///   ``AudioSources/resolve(preferring:)``.
    ///
    /// - Note: Under ``QualityPolicy/automatic(interval:downgradeAfterInterruptions:)`` the
    ///   player may move the rung again on its own. Use ``QualityPolicy/fixed`` to make a
    ///   listener's choice stick.
    public func setQuality(_ quality: AudioQuality) {
        send(.setQuality(quality))
    }

    // MARK: Wiring

    /// Configures and activates the audio session ahead of the first track.
    ///
    /// The player activates the session on its own when playback starts, so this is optional.
    /// Call it when you would rather a conflict with another app surface as a thrown error at a
    /// moment you control, instead of as silence once the listener presses play.
    ///
    /// - Throws: ``AudioPlayerError/audioSessionFailed(_:)`` when `AVAudioSession` refuses to
    ///   take the category or to activate — typically because another app holds a session that
    ///   will not yield. The associated ``PlaybackFailure`` carries the underlying domain and
    ///   code. This is the only case this method produces.
    ///
    /// - Note: Does nothing, and cannot throw, while
    ///   ``AudioSessionPolicy/isManaged`` is `false` or the session is already active. There is
    ///   no audio session on macOS, where this is always a no-op.
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
        #if canImport(AVFAudio) && !os(watchOS)
            audioProcessing.setAvailable(engine.supportsAudioProcessing)
        #endif

        guard machine.configuration.publishesNowPlayingInfo else {
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
