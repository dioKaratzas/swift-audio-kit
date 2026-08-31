//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// Where the playhead is and what surrounds it.
///
/// Published on ``AudioPlayer/progress``, refreshed every
/// ``AudioPlayerConfiguration/progressUpdateInterval``, and reset to ``zero`` on every track
/// change. Three of the four fields are optional, and each `nil` has a specific meaning
/// rather than signalling an error.
public struct PlaybackProgress: Sendable, Hashable {
    /// How far into the stream the playhead sits.
    ///
    /// Measured from the start of the stream, not from the start of ``seekable``, so it keeps
    /// climbing on a live stream whose window slides forward.
    public var elapsed: Duration

    /// The length of the current track, or `nil` when there is none to report.
    ///
    /// `nil` is not an error: either the engine has not resolved a length yet, or the track is
    /// a live stream and has no end to measure against. ``isLive`` covers both.
    public var duration: Duration?

    /// What has been fetched around the playhead, or `nil` before the engine reports any.
    ///
    /// The range surrounds the playhead rather than starting at zero, because seeking
    /// discards what was buffered elsewhere.
    public var buffered: ClosedRange<Duration>?

    /// What can be seeked to, or `nil` before the engine reports a range.
    ///
    /// For a live stream this is the window the server still keeps, which slides forward as
    /// the broadcast continues, so its lower bound is rarely zero.
    ///
    /// - Note: The exact edges are not reliably seekable, which is why
    ///   ``clampingToSeekableRange(_:padding:)`` keeps a second's padding inside them.
    public var seekable: ClosedRange<Duration>?

    /// Creates a progress snapshot.
    ///
    /// - Parameters:
    ///   - elapsed: Where the playhead sits, measured from the start of the stream. Defaults
    ///     to `.zero`.
    ///   - duration: The track's length, or `nil` for a live or unresolved one. Defaults to
    ///     `nil`.
    ///   - buffered: What has been fetched around the playhead. Defaults to `nil`.
    ///   - seekable: What can be seeked to. Defaults to `nil`.
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

    /// Nothing playing: a playhead at zero with nothing else known.
    ///
    /// What ``AudioPlayer/progress`` is reset to on every track change.
    public static let zero = PlaybackProgress()

    /// How far through the track the playhead is, from `0` to `1`.
    ///
    /// Clamped into `0...1`, so a playhead that has run slightly past a reported duration
    /// still reads as `1`.
    ///
    /// - Note: `nil` means there is no fraction to compute, not that something went wrong:
    ///   the track is live, its duration has not resolved yet, or the duration is zero. Prefer
    ///   an indeterminate indicator over a bar pinned at zero.
    public var fraction: Double? {
        guard let duration, duration > .zero else {
            return nil
        }
        return min(max(elapsed.totalSeconds / duration.totalSeconds, 0), 1)
    }

    /// How much of the track is left to play.
    ///
    /// Never negative: a playhead past the reported duration reads as `.zero`. `nil` wherever
    /// ``duration`` is, and for the same reasons.
    public var remaining: Duration? {
        guard let duration else {
            return nil
        }
        return max(duration - elapsed, .zero)
    }

    /// How much runway is buffered ahead of the playhead.
    ///
    /// The distance from ``elapsed`` to the far edge of ``buffered``, clamped at `.zero`, so
    /// roughly how long playback could continue if the connection dropped now. `nil` before
    /// the engine reports any buffer.
    public var bufferedAhead: Duration? {
        guard let buffered else {
            return nil
        }
        return max(buffered.upperBound - elapsed, .zero)
    }

    /// Whether the track has no end to measure against.
    ///
    /// - Note: True both for a genuine live stream and for the short window before a length
    ///   resolves on an on-demand track. To tell those apart, wait for
    ///   ``AudioPlayerEvent/durationResolved(_:for:)``, which a live stream never sends.
    public var isLive: Bool {
        duration == nil
    }

    /// Returns a time pulled inside the seekable window.
    ///
    /// The player applies this before every seek unless you opt out, because the exact edges
    /// of ``seekable`` are not reliably seekable and a request landing on one can be refused.
    ///
    /// - Parameters:
    ///   - time: The time to clamp, measured from the start of the stream.
    ///   - padding: How far inside each edge of ``seekable`` to stay. Defaults to one second.
    ///     A padding wider than the window itself inverts the bounds, so keep it small
    ///     relative to what the server retains.
    /// - Returns: `time` clamped into the padded seekable window. When ``seekable`` is `nil`
    ///   there is no window to clamp against, and the result is `time` with any negative value
    ///   raised to `.zero`.
    public func clampingToSeekableRange(_ time: Duration, padding: Duration = .seconds(1)) -> Duration {
        guard let seekable else {
            return max(time, .zero)
        }
        return min(max(time, seekable.lowerBound + padding), seekable.upperBound - padding)
    }
}
