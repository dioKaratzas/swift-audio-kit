//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// Every knob the player reads, gathered so a whole behaviour can be swapped in one assignment.
public struct AudioPlayerConfiguration: Sendable, Hashable {
    /// The rung to start each item on, before the automatic policy moves it.
    public var defaultQuality: AudioQuality

    /// Whether the rung moves on its own in response to stalls.
    public var quality: QualityPolicy

    /// How hard to try again when the engine reports a failure.
    public var retry: RetryPolicy

    /// How much to fetch ahead, and what bitrate ceiling to accept.
    public var buffering: BufferingPolicy

    /// Playback fails once this much passes without a usable connection. Local files never wait.
    public var maximumConnectionLossTime: Duration

    /// Only ever resumes a pause the listener did not ask for, and only when the system says
    /// resuming is appropriate.
    public var resumesAfterInterruption: Bool

    /// Reloads the track from the beginning; only the retry path picks up where it stalled.
    public var resumesAfterConnectionLoss: Bool

    /// How often the playhead is republished, which sets the granularity of any progress bar.
    public var progressUpdateInterval: Duration

    /// Whether the player owns the audio session, and how it shares the output.
    public var audioSession: AudioSessionPolicy

    /// Whether the lock screen and Control Centre are kept up to date.
    public var updatesNowPlayingInfo: Bool

    /// Every default here matches `default`, so named arguments override one knob at a time.
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
        updatesNowPlayingInfo: Bool = true
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
        self.updatesNowPlayingInfo = updatesNowPlayingInfo
    }

    /// Sensible for music: automatic quality, a minute of connection grace, managed session.
    public static let `default` = AudioPlayerConfiguration()

    /// Buffers two minutes ahead at a fixed quality, for long spoken tracks over patchy links.
    public static let podcast = AudioPlayerConfiguration(
        quality: .fixed,
        buffering: BufferingPolicy(preferredForwardDuration: .seconds(120))
    )

    /// Never stops retrying, because a live stream dropping out is routine rather than fatal.
    public static let liveRadio = AudioPlayerConfiguration(
        quality: .fixed,
        retry: RetryPolicy(maximumAttempts: .max, timeout: .seconds(5)),
        buffering: BufferingPolicy(preferredForwardDuration: .seconds(10))
    )
}

/// Whether the quality rung is left where it was put, or moved in response to stalls.
public enum QualityPolicy: Sendable, Hashable {
    /// Stays on whatever rung was last set, however badly the stream behaves.
    case fixed

    /// Steps down after that many stalls, and only steps back up once a stretch has been clean.
    case automatic(interval: Duration = .seconds(600), downgradeAfterInterruptions: Int = 5)

    /// Whether the rung is allowed to move on its own.
    public var isAutomatic: Bool {
        if case .automatic = self {
            true
        } else {
            false
        }
    }

    /// How long to wait before trying a higher rung, and `nil` under `fixed`.
    public var interval: Duration? {
        guard case let .automatic(interval, _) = self else {
            return nil
        }
        return interval
    }

    /// How many stalls force a step down, and `nil` under `fixed`.
    public var downgradeAfterInterruptions: Int? {
        guard case let .automatic(_, count) = self else {
            return nil
        }
        return count
    }
}

/// How hard to try again after the engine reports a failure, before giving up on the item.
public struct RetryPolicy: Sendable, Hashable {
    /// Attempts per item, reset on every track change; `Int.max` never gives up.
    public var maximumAttempts: Int

    /// The wait between attempts, not a deadline for one.
    public var timeout: Duration

    /// Ten attempts ten seconds apart, which rides out a couple of minutes of trouble.
    public init(maximumAttempts: Int = 10, timeout: Duration = .seconds(10)) {
        self.maximumAttempts = maximumAttempts
        self.timeout = timeout
    }

    /// Fails on the first error, without waiting out a single timeout.
    public static let none = RetryPolicy(maximumAttempts: 0)
}

/// Hints passed straight to AVFoundation, which treats every one of them as advisory.
public struct BufferingPolicy: Sendable, Hashable {
    /// How much to fetch ahead of the playhead; `nil` leaves the system to decide.
    public var preferredForwardDuration: Duration?

    /// A ceiling in bits per second for adaptive streams; `nil` allows the highest on offer.
    public var preferredPeakBitRate: Double?

    /// Applies to metered and Low Data Mode links alike, falling back to `preferredPeakBitRate`.
    public var preferredPeakBitRateOnExpensiveNetworks: Double?

    /// Everything `nil`, which leaves all three decisions to AVFoundation.
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
