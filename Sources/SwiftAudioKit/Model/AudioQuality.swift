//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// An item's own streams ranked against each other, rather than any absolute bitrate.
public enum AudioQuality: Int, Sendable, Hashable, CaseIterable, Comparable {
    /// The smallest stream an item offers.
    case low

    /// The middle stream, where an item offers three.
    case medium

    /// The largest stream an item offers.
    case high

    /// The rung below, or `nil` at `low`.
    public var lower: AudioQuality? {
        AudioQuality(rawValue: rawValue - 1)
    }

    /// The rung above, or `nil` at `high`.
    public var higher: AudioQuality? {
        AudioQuality(rawValue: rawValue + 1)
    }

    /// Orders the rungs upwards from `low`.
    public static func < (lhs: AudioQuality, rhs: AudioQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
