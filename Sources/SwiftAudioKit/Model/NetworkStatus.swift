//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// What the current network path affords, as far as playback is concerned.
///
/// The player watches the system's path monitor, publishes the result on
/// ``AudioPlayer/network``, and acts on it: a path that stops being usable moves a remote
/// track into ``PlaybackState/waitingForConnection(_:)``, and one that reports
/// ``prefersReducedData`` switches the bitrate ceiling to
/// ``BufferingPolicy/preferredPeakBitRateOnExpensiveNetworks``.
public struct NetworkStatus: Sendable, Hashable {
    /// Whether a route exists, with a third case for not having heard yet.
    public enum Reachability: Sendable, Hashable {
        /// No path has been reported yet.
        ///
        /// Where every player starts, and also where a path sits when the system says it
        /// requires a connection to be brought up. Deliberately distinct from ``unavailable``;
        /// see ``NetworkStatus/isUsable``.
        case unknown

        /// The system positively reports that no route exists.
        ///
        /// The only reachability that stops playback of a remote track.
        case unavailable

        /// A route exists, though it may be metered or constrained.
        case available
    }

    /// Which kind of link is carrying the traffic.
    public enum Interface: Sendable, Hashable {
        /// A wireless local network.
        case wifi

        /// A mobile network, which is usually metered.
        case cellular

        /// Ethernet, or anything else physically attached.
        case wired

        /// A link the monitor could not place, such as a VPN or a loopback interface.
        case other
    }

    /// Whether a route exists.
    ///
    /// Starts at ``Reachability/unknown`` and stays there until the system reports a path.
    public var reachability: Reachability

    /// The link carrying the traffic, or `nil` when there is no route to describe.
    public var interface: Interface?

    /// Whether the system considers the link to cost money.
    ///
    /// - Note: This is the system's own judgement, not an inference from ``interface``.
    ///   Tethered Wi-Fi can be expensive and a corporate cellular plan may not be, so branch
    ///   on this rather than on the interface kind.
    public var isExpensive: Bool

    /// Whether Low Data Mode is switched on for this link.
    public var isConstrained: Bool

    /// Creates a status describing a network path.
    ///
    /// - Parameters:
    ///   - reachability: Whether a route exists. Defaults to ``Reachability/unknown``, which
    ///     counts as usable.
    ///   - interface: The kind of link carrying traffic, or `nil` when there is no route.
    ///     Defaults to `nil`.
    ///   - isExpensive: Whether the system considers the link metered. Defaults to `false`.
    ///   - isConstrained: Whether Low Data Mode is on. Defaults to `false`.
    public init(
        reachability: Reachability = .unknown,
        interface: Interface? = nil,
        isExpensive: Bool = false,
        isConstrained: Bool = false
    ) {
        self.reachability = reachability
        self.interface = interface
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }

    /// Nothing heard yet, which is the state a player is created in.
    ///
    /// ``isUsable`` is `true` for this value, so a player created before the first path report
    /// will still start a remote track.
    public static let unknown = NetworkStatus()

    /// A positive report that no route exists.
    ///
    /// The one status that moves a remote track into
    /// ``PlaybackState/waitingForConnection(_:)``.
    public static let unavailable = NetworkStatus(reachability: .unavailable)

    /// Whether playback over the current path should be attempted.
    ///
    /// Only ``Reachability/unavailable`` counts as unusable. ``Reachability/unknown`` counts
    /// as **usable**, so a player created before the first path report does not refuse to
    /// start, and a path the system has not yet brought up is not mistaken for an outage.
    ///
    /// - Important: Usable is not a promise of throughput. A path that is ``isExpensive`` or
    ///   ``isConstrained`` is still usable; consult ``prefersReducedData`` to decide whether
    ///   to ask for less data.
    public var isUsable: Bool {
        reachability != .unavailable
    }

    /// Whether the link is one worth spending less data on.
    ///
    /// `true` when the link is metered or in Low Data Mode. The player consults this when
    /// building each load request and applies
    /// ``BufferingPolicy/preferredPeakBitRateOnExpensiveNetworks`` in place of
    /// ``BufferingPolicy/preferredPeakBitRate`` while it holds.
    public var prefersReducedData: Bool {
        isExpensive || isConstrained
    }
}
