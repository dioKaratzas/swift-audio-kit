//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public struct PlaybackProgress: Sendable, Hashable {
    public var elapsed: Duration
    public var duration: Duration?
    public var buffered: ClosedRange<Duration>?
    public var seekable: ClosedRange<Duration>?

    public init(
        elapsed: Duration = .zero,
        duration: Duration? = nil,
        buffered: ClosedRange<Duration>? = nil,
        seekable: ClosedRange<Duration>? = nil
    ) {
        self.elapsed = elapsed
        self.duration = duration
        self.buffered = buffered
        self.seekable = seekable
    }

    public static let zero = PlaybackProgress()

    /// `nil` for live streams, which have no end to measure against.
    public var fraction: Double? {
        guard let duration, duration > .zero else {
            return nil
        }
        return min(max(elapsed.totalSeconds / duration.totalSeconds, 0), 1)
    }

    public var remaining: Duration? {
        guard let duration else {
            return nil
        }
        return max(duration - elapsed, .zero)
    }

    public var bufferedAhead: Duration? {
        guard let buffered else {
            return nil
        }
        return max(buffered.upperBound - elapsed, .zero)
    }

    public var isLive: Bool {
        duration == nil
    }

    public func clampingToSeekableRange(_ time: Duration, padding: Duration = .seconds(1)) -> Duration {
        guard let seekable else {
            return max(time, .zero)
        }
        return min(max(time, seekable.lowerBound + padding), seekable.upperBound - padding)
    }
}
