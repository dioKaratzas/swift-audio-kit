//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public struct AudioPlayerConfiguration: Sendable, Hashable {
    public var defaultQuality: AudioQuality
    public var quality: QualityPolicy
    public var retry: RetryPolicy
    public var buffering: BufferingPolicy
    public var maximumConnectionLossTime: Duration
    public var resumesAfterInterruption: Bool
    public var resumesAfterConnectionLoss: Bool
    public var progressUpdateInterval: Duration

    public init(
        defaultQuality: AudioQuality = .high,
        quality: QualityPolicy = .automatic(),
        retry: RetryPolicy = RetryPolicy(),
        buffering: BufferingPolicy = BufferingPolicy(),
        maximumConnectionLossTime: Duration = .seconds(60),
        resumesAfterInterruption: Bool = true,
        resumesAfterConnectionLoss: Bool = true,
        progressUpdateInterval: Duration = .seconds(1)
    ) {
        self.defaultQuality = defaultQuality
        self.quality = quality
        self.retry = retry
        self.buffering = buffering
        self.maximumConnectionLossTime = maximumConnectionLossTime
        self.resumesAfterInterruption = resumesAfterInterruption
        self.resumesAfterConnectionLoss = resumesAfterConnectionLoss
        self.progressUpdateInterval = progressUpdateInterval
    }

    public static let `default` = AudioPlayerConfiguration()

    public static let podcast = AudioPlayerConfiguration(
        quality: .fixed,
        buffering: BufferingPolicy(preferredForwardDuration: .seconds(120))
    )

    public static let liveRadio = AudioPlayerConfiguration(
        quality: .fixed,
        retry: RetryPolicy(maximumAttempts: .max, timeout: .seconds(5)),
        buffering: BufferingPolicy(preferredForwardDuration: .seconds(10))
    )
}

public enum QualityPolicy: Sendable, Hashable {
    case fixed
    case automatic(interval: Duration = .seconds(600), downgradeAfterInterruptions: Int = 5)

    public var isAutomatic: Bool {
        if case .automatic = self {
            true
        } else {
            false
        }
    }

    public var interval: Duration? {
        guard case let .automatic(interval, _) = self else {
            return nil
        }
        return interval
    }

    public var downgradeAfterInterruptions: Int? {
        guard case let .automatic(_, count) = self else {
            return nil
        }
        return count
    }
}

public struct RetryPolicy: Sendable, Hashable {
    public var maximumAttempts: Int
    public var timeout: Duration

    public init(maximumAttempts: Int = 10, timeout: Duration = .seconds(10)) {
        self.maximumAttempts = maximumAttempts
        self.timeout = timeout
    }

    public static let none = RetryPolicy(maximumAttempts: 0)
}

public struct BufferingPolicy: Sendable, Hashable {
    public var preferredForwardDuration: Duration?
    public var preferredPeakBitRate: Double?

    public init(preferredForwardDuration: Duration? = nil, preferredPeakBitRate: Double? = nil) {
        self.preferredForwardDuration = preferredForwardDuration
        self.preferredPeakBitRate = preferredPeakBitRate
    }
}
