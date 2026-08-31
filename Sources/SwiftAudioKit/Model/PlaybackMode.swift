//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// What the queue does when it runs off either end.
public enum RepeatMode: Sendable, Hashable, CaseIterable {
    /// The queue stops once it runs out.
    case off

    /// Advancing and retreating both stay on the current track rather than moving.
    case one

    /// The queue wraps around at either end and never runs out.
    case all

    /// The next rung for a button that cycles: off, all, one, and back.
    public var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

/// Repeat and shuffle carried together, so the queue can adapt to a change in both at once.
public struct PlaybackMode: Sendable, Hashable {
    /// What happens when the queue reaches an end.
    public var repeatMode: RepeatMode

    /// Whether playback order has been shuffled away from the order items were added in.
    public var isShuffled: Bool

    /// Defaults to playing straight through, once.
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
