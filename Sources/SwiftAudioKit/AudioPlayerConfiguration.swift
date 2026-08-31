//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// Every knob the player reads, gathered so a whole behaviour can be swapped in one assignment.
///
/// Pass one to ``AudioPlayer/init(configuration:remoteCommands:)``, or assign to
/// ``AudioPlayer/configuration`` at any time — including mid-track, where the change takes
/// effect immediately rather than at the next item. ``default``, ``podcast`` and ``liveRadio``
/// cover the common shapes; build one directly to set the policies yourself.
///
///     var configuration = AudioPlayerConfiguration.podcast
///     configuration.maximumConnectionLossTime = .seconds(120)
///     configuration.resumesAfterInterruption = false
///     player.configuration = configuration
public struct AudioPlayerConfiguration: Sendable, Hashable {
    /// The rung to start each item on, before the automatic policy moves it.
    ///
    /// Also the rung ``AudioPlayer/quality`` reports until something changes it.
    public var defaultQuality: AudioQuality

    /// Whether the quality rung moves on its own in response to stalls.
    public var quality: QualityPolicy

    /// How hard to try again when the engine reports a failure.
    public var retry: RetryPolicy

    /// How much to fetch ahead, and what bitrate ceiling to accept.
    public var buffering: BufferingPolicy

    /// How long playback waits for a usable connection before failing.
    ///
    /// The player holds a remote track in ``PlaybackState/waitingForConnection(_:)`` for this
    /// long, then fails with ``AudioPlayerError/connectionLost(after:)``.
    ///
    /// - Note: Local items never wait, since they need no route.
    public var maximumConnectionLossTime: Duration

    /// Whether playback resumes by itself after an interruption ends.
    ///
    /// - Important: Only ever resumes a pause the listener did not ask for, and only when the
    ///   system says resuming is appropriate. A pause with reason ``PauseReason/user`` is never
    ///   resumed automatically, whatever this is set to.
    public var resumesAfterInterruption: Bool

    /// Whether playback resumes by itself once a usable connection returns.
    ///
    /// - Note: The track is reloaded from the beginning. Only the retry path picks up where it
    ///   stalled. When this is `false` the player settles into
    ///   ``PauseReason/stalled`` instead, loaded and ready to be told to play.
    public var resumesAfterConnectionLoss: Bool

    /// How often the playhead is republished.
    ///
    /// Sets the granularity of anything drawn from ``AudioPlayer/progress``. Shortening it
    /// makes a progress bar smoother at the cost of more main-actor work per second.
    public var progressUpdateInterval: Duration

    /// Whether the player owns the audio session, and how it shares the output.
    public var audioSession: AudioSessionPolicy

    /// Whether the lock screen and Control Center are kept up to date.
    ///
    /// Turn it off only when something else in your process publishes Now Playing information;
    /// two publishers fight, and the listener sees whichever wrote last.
    public var publishesNowPlayingInfo: Bool

    /// Creates a configuration.
    ///
    /// Every default here matches ``default``, so named arguments override one knob at a time.
    ///
    /// - Parameters:
    ///   - defaultQuality: The rung each item starts on. Defaults to ``AudioQuality/high``.
    ///   - quality: Whether the rung moves on its own. Defaults to
    ///     ``QualityPolicy/automatic(interval:downgradeAfterInterruptions:)`` with its own
    ///     defaults.
    ///   - retry: How hard to try again after a failure. Defaults to ten attempts ten seconds
    ///     apart.
    ///   - buffering: Buffering and bitrate hints. Defaults to leaving all three decisions to
    ///     AVFoundation.
    ///   - maximumConnectionLossTime: How long a remote track waits for a route before failing.
    ///     Defaults to 60 seconds. Local items never wait.
    ///   - resumesAfterInterruption: Whether to resume after an interruption the system says is
    ///     safe to resume from. Defaults to `true`.
    ///   - resumesAfterConnectionLoss: Whether to reload and resume when a route returns.
    ///     Defaults to `true`.
    ///   - progressUpdateInterval: How often the playhead is republished. Defaults to one
    ///     second.
    ///   - audioSession: Whether the player owns the audio session. Defaults to
    ///     ``AudioSessionPolicy/managed``.
    ///   - publishesNowPlayingInfo: Whether to publish Now Playing information. Defaults to
    ///     `true`.
    public init(
        defaultQuality: AudioQuality = .high,
        quality: QualityPolicy = .automatic(),
        retry: RetryPolicy = RetryPolicy(),
        buffering: BufferingPolicy = BufferingPolicy(),
        maximumConnectionLossTime: Duration = .seconds(60),
        resumesAfterInterruption: Bool = true,
        resumesAfterConnectionLoss: Bool = true,
        progressUpdateInterval: Duration = .seconds(1),
        audioSession: AudioSessionPolicy = .managed,
        publishesNowPlayingInfo: Bool = true
    ) {
        self.defaultQuality = defaultQuality
        self.quality = quality
        self.retry = retry
        self.buffering = buffering
        self.maximumConnectionLossTime = maximumConnectionLossTime
        self.resumesAfterInterruption = resumesAfterInterruption
        self.resumesAfterConnectionLoss = resumesAfterConnectionLoss
        self.progressUpdateInterval = progressUpdateInterval
        self.audioSession = audioSession
        self.publishesNowPlayingInfo = publishesNowPlayingInfo
    }

    /// Sensible for music: automatic quality, a minute of connection grace, managed session.
    ///
    /// What ``AudioPlayer/init(configuration:remoteCommands:)`` uses unless you say otherwise.
    public static let `default` = AudioPlayerConfiguration()

    /// Buffers two minutes ahead at a fixed quality, for long spoken tracks over patchy links.
    ///
    /// Quality is pinned because stepping a spoken-word stream down buys little and is audible.
    public static let podcast = AudioPlayerConfiguration(
        quality: .fixed,
        buffering: BufferingPolicy(preferredForwardDuration: .seconds(120))
    )

    /// Never stops retrying, because a live stream dropping out is routine rather than fatal.
    ///
    /// Retries every five seconds without limit and buffers only ten seconds ahead, since a
    /// live stream cannot run further ahead than the broadcast itself.
    public static let liveRadio = AudioPlayerConfiguration(
        quality: .fixed,
        retry: RetryPolicy(maximumAttempts: .max, timeout: .seconds(5)),
        buffering: BufferingPolicy(preferredForwardDuration: .seconds(10))
    )
}

/// Whether the quality rung is left where it was put, or moved in response to stalls.
public enum QualityPolicy: Sendable, Hashable {
    /// Stays on whatever rung was last set, however badly the stream behaves.
    ///
    /// The right choice for live radio and for spoken audio, where the rungs differ little.
    case fixed

    /// Steps the rung down after repeated stalls, and back up after a clean stretch.
    ///
    /// The associated values are how long a clean stretch must last before the rung is tried
    /// one higher, and how many stalls force a step down. A stall inside a window delays the
    /// upgrade rather than preventing every later one: each window re-arms the next and starts
    /// counting again.
    case automatic(interval: Duration = .seconds(600), downgradeAfterInterruptions: Int = 5)

    /// Whether the rung is allowed to move on its own.
    public var isAutomatic: Bool {
        if case .automatic = self {
            true
        } else {
            false
        }
    }

    /// How long to wait before trying a higher rung.
    ///
    /// `nil` under ``fixed``, where no upgrade is ever scheduled.
    public var interval: Duration? {
        guard case let .automatic(interval, _) = self else {
            return nil
        }
        return interval
    }

    /// How many stalls force a step down.
    ///
    /// `nil` under ``fixed``, where stalls are not counted at all.
    public var downgradeAfterInterruptions: Int? {
        guard case let .automatic(_, count) = self else {
            return nil
        }
        return count
    }
}

/// How hard to try again after the engine reports a failure, before giving up on the item.
public struct RetryPolicy: Sendable, Hashable {
    /// Attempts per item, reset on every track change.
    ///
    /// `Int.max` never gives up, which is what ``AudioPlayerConfiguration/liveRadio`` uses.
    /// Exhausting the budget fails with ``AudioPlayerError/retryLimitReached(attempts:)``.
    public var maximumAttempts: Int

    /// The wait between attempts.
    ///
    /// - Important: This is the gap before the next attempt, not a deadline for one. An attempt
    ///   that hangs is bounded by
    ///   ``AudioPlayerConfiguration/maximumConnectionLossTime`` and by AVFoundation's own
    ///   timeouts, not by this.
    public var timeout: Duration

    /// Creates a retry policy.
    ///
    /// - Parameters:
    ///   - maximumAttempts: How many attempts each item gets before the player gives up.
    ///     Defaults to `10`. Use `Int.max` to retry indefinitely, and `0` to fail on the first
    ///     error.
    ///   - timeout: How long to wait between attempts. Defaults to 10 seconds, which with the
    ///     default attempt count rides out a couple of minutes of trouble.
    public init(maximumAttempts: Int = 10, timeout: Duration = .seconds(10)) {
        self.maximumAttempts = maximumAttempts
        self.timeout = timeout
    }

    /// Fails on the first error, without waiting out a single timeout.
    public static let none = RetryPolicy(maximumAttempts: 0)
}

/// Hints passed straight to AVFoundation, which treats every one of them as advisory.
///
/// - Important: None of these is a guarantee. AVFoundation weighs them against the network, the
///   device and the stream, and may buffer more or less than asked.
public struct BufferingPolicy: Sendable, Hashable {
    /// How much to fetch ahead of the playhead.
    ///
    /// `nil` leaves the system to decide, which is usually right for on-demand audio. Raise it
    /// for spoken audio over a patchy link; lower it for live streams, which cannot run ahead
    /// of the broadcast anyway.
    public var preferredForwardDuration: Duration?

    /// A ceiling in bits per second for adaptive streams.
    ///
    /// `nil` allows the highest variant on offer. Applies to HLS and other adaptive formats;
    /// a single-file stream has no variants to choose between.
    public var preferredPeakBitRate: Double?

    /// The ceiling to use on metered and Low Data Mode links.
    ///
    /// The player substitutes this for ``preferredPeakBitRate`` whenever
    /// ``NetworkStatus/prefersReducedData`` holds. `nil` falls back to
    /// ``preferredPeakBitRate``, which in turn may be `nil`.
    public var preferredPeakBitRateOnExpensiveNetworks: Double?

    /// Creates a buffering policy.
    ///
    /// - Parameters:
    ///   - preferredForwardDuration: How much to fetch ahead of the playhead, or `nil` to leave
    ///     it to AVFoundation. Defaults to `nil`.
    ///   - preferredPeakBitRate: A ceiling in bits per second, or `nil` for no ceiling.
    ///     Defaults to `nil`.
    ///   - preferredPeakBitRateOnExpensiveNetworks: The ceiling to use on metered and Low Data
    ///     Mode links, or `nil` to reuse `preferredPeakBitRate`. Defaults to `nil`.
    public init(
        preferredForwardDuration: Duration? = nil,
        preferredPeakBitRate: Double? = nil,
        preferredPeakBitRateOnExpensiveNetworks: Double? = nil
    ) {
        self.preferredForwardDuration = preferredForwardDuration
        self.preferredPeakBitRate = preferredPeakBitRate
        self.preferredPeakBitRateOnExpensiveNetworks = preferredPeakBitRateOnExpensiveNetworks
    }
}
