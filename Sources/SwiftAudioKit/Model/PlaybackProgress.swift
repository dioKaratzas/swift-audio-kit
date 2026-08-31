//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// Where the playhead is and what surrounds it, refreshed on the configured interval.
public struct PlaybackProgress: Sendable, Hashable {
    /// How far in the playhead sits, measured from the start of the stream rather than the seekable range.
    public var elapsed: Duration

    /// `nil` until the engine resolves it, and permanently `nil` for a live stream.
    public var duration: Duration?

    /// What has been fetched around the playhead, or `nil` before the engine reports any.
    public var buffered: ClosedRange<Duration>?

    /// What can be seeked to, which for a live stream is the window the server still keeps.
    public var seekable: ClosedRange<Duration>?

    /// Defaults to a playhead at zero with nothing else known yet.
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

    /// Nothing playing, which is what the player resets to on every track change.
    public static let zero = PlaybackProgress()

    /// `nil` for live streams, which have no end to measure against.
    public var fraction: Double? {
        guard let duration, duration > .zero else {
            return nil
        }
        return min(max(elapsed.totalSeconds / duration.totalSeconds, 0), 1)
    }

    /// Never negative, and `nil` wherever `duration` is.
    public var remaining: Duration? {
        guard let duration else {
            return nil
        }
        return max(duration - elapsed, .zero)
    }

    /// How much runway is left before a stall, and `nil` before any buffer is reported.
    public var bufferedAhead: Duration? {
        guard let buffered else {
            return nil
        }
        return max(buffered.upperBound - elapsed, .zero)
    }

    /// True before a duration has resolved as well as for a genuine live stream.
    public var isLive: Bool {
        duration == nil
    }

    /// Keeps a second's padding inside the range, whose exact edges are not reliably seekable.
    public func clampingToSeekableRange(_ time: Duration, padding: Duration = .seconds(1)) -> Duration {
        guard let seekable else {
            return max(time, .zero)
        }
        return min(max(time, seekable.lowerBound + padding), seekable.upperBound - padding)
    }
}
