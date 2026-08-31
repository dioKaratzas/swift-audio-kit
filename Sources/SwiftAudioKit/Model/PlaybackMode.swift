//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// What the queue does when it runs off either end.
///
/// Set it through ``AudioPlayer/repeatMode``, which takes effect immediately and applies to
/// the next move rather than the track already playing.
public enum RepeatMode: Sendable, Hashable, CaseIterable {
    /// The queue stops once it runs out.
    ///
    /// Running off the end emits ``AudioPlayerEvent/queueExhausted`` and stops the player,
    /// which also hands back the audio session.
    case off

    /// The current track repeats, and the queue never moves.
    ///
    /// - Important: Under this mode ``AudioPlayer/next()`` and ``AudioPlayer/previous()``
    ///   restart the current track rather than moving to another one.
    case one

    /// The queue wraps around at either end and never runs out.
    ///
    /// ``AudioPlayer/hasNext`` is therefore always `true` while anything is queued, and
    /// ``AudioPlayerEvent/queueExhausted`` is never emitted.
    case all

    /// The mode a cycling button should move to next.
    ///
    /// Cycles ``off`` to ``all`` to ``one`` and back, matching the order the system music
    /// apps use.
    public var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

/// Repeat and shuffle carried together, so the queue can adapt to a change in both at once.
///
/// ``AudioPlayer`` exposes the two halves separately as ``AudioPlayer/repeatMode`` and
/// ``AudioPlayer/isShuffled``; this type is what those assignments are folded into before
/// reaching ``PlaybackQueue/mode``.
public struct PlaybackMode: Sendable, Hashable {
    /// What happens when the queue reaches an end.
    public var repeatMode: RepeatMode

    /// Whether playback order has been shuffled away from the order items were added in.
    ///
    /// Turning this on reshuffles only the tracks that have not played yet and holds the
    /// current track in place, so the track playing does not change under the listener.
    public var isShuffled: Bool

    /// Creates a mode from its two halves.
    ///
    /// - Parameters:
    ///   - repeatMode: What happens at the ends of the queue. Defaults to ``RepeatMode/off``.
    ///   - isShuffled: Whether to play in shuffled order. Defaults to `false`.
    public init(repeatMode: RepeatMode = .off, isShuffled: Bool = false) {
        self.repeatMode = repeatMode
        self.isShuffled = isShuffled
    }

    /// Straight through, stopping at the end.
    public static let normal = PlaybackMode()

    /// Shuffled, stopping once every track has played.
    public static let shuffle = PlaybackMode(isShuffled: true)

    /// The current track over and over.
    public static let repeatOne = PlaybackMode(repeatMode: .one)

    /// Straight through, wrapping around indefinitely.
    public static let repeatAll = PlaybackMode(repeatMode: .all)
}
