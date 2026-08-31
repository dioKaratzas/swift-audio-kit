//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// An item's own streams ranked against each other, rather than any absolute bitrate.
///
/// A rung says nothing about kilobits per second. It says only which of the URLs in an
/// ``AudioSources`` value to reach for, so `high` on a spoken-word feed and `high` on a
/// music catalogue may be very different streams.
///
/// Set the starting rung with ``AudioPlayerConfiguration/defaultQuality``, change it during
/// playback with ``AudioPlayer/setQuality(_:)``, and read the rung actually in use from
/// ``AudioPlayer/quality``. Under
/// ``QualityPolicy/automatic(interval:downgradeAfterInterruptions:)`` the player moves the
/// rung on its own in response to stalls.
///
/// - Note: An item need not offer all three. ``AudioSources/resolve(preferring:)`` falls
///   back to the nearest rung it has.
public enum AudioQuality: Int, Sendable, Hashable, CaseIterable, Comparable {
    /// The smallest stream an item offers.
    ///
    /// Where the automatic policy lands after repeated stalls, and a sensible ceiling on a
    /// link that reports ``NetworkStatus/prefersReducedData``.
    case low

    /// The middle stream, where an item offers three.
    ///
    /// Items commonly skip this rung. Asking for it on an item that offers only `low` and
    /// `high` resolves to `low`, because ties are broken downwards.
    case medium

    /// The largest stream an item offers.
    ///
    /// The default for ``AudioPlayerConfiguration/defaultQuality``, and the rung the
    /// automatic policy climbs back to after a clean stretch.
    case high

    /// The rung below this one, or `nil` at ``low``.
    ///
    /// Independent of what any particular item offers: this walks the enumeration, not an
    /// ``AudioSources`` value. The automatic quality policy uses it to step down.
    public var lower: AudioQuality? {
        AudioQuality(rawValue: rawValue - 1)
    }

    /// The rung above this one, or `nil` at ``high``.
    ///
    /// Independent of what any particular item offers: this walks the enumeration, not an
    /// ``AudioSources`` value. The automatic quality policy uses it to step back up.
    public var higher: AudioQuality? {
        AudioQuality(rawValue: rawValue + 1)
    }

    /// Returns a Boolean value indicating whether one rung sits below another.
    ///
    /// Orders the rungs upwards from ``low``, so `low < medium < high`.
    ///
    /// - Parameters:
    ///   - lhs: The rung to compare on the left.
    ///   - rhs: The rung to compare against.
    /// - Returns: `true` when `lhs` is a smaller stream than `rhs`.
    public static func < (lhs: AudioQuality, rhs: AudioQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
