//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// What the current network path affords, as far as playback is concerned.
public struct NetworkStatus: Sendable, Hashable {
    /// Whether a route exists, with a third case for not having heard yet.
    public enum Reachability: Sendable, Hashable {
        /// No path has been reported yet, which is where every player starts.
        case unknown

        /// The system positively reports no route.
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

        /// Ethernet, and anything else physically attached.
        case wired

        /// A link the monitor could not place, such as a VPN or a loopback.
        case other
    }

    /// Whether a route exists; `unknown` until the first path is reported.
    public var reachability: Reachability

    /// The link carrying the traffic, or `nil` when there is no route to describe.
    public var interface: Interface?

    /// The system's own view of whether the link costs money, not an inference from `interface`.
    public var isExpensive: Bool

    /// Low Data Mode is switched on for this link.
    public var isConstrained: Bool

    /// Defaults to having heard nothing, which counts as usable.
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
    public static let unknown = NetworkStatus()

    /// A positive report of no route, which is what stops playback.
    public static let unavailable = NetworkStatus(reachability: .unavailable)

    /// Only a positive report of no route counts as unusable, so playback is never
    /// blocked before the first path arrives.
    public var isUsable: Bool {
        reachability != .unavailable
    }

    /// Worth dropping quality for, whether the link is metered or in Low Data Mode.
    public var prefersReducedData: Bool {
        isExpensive || isConstrained
    }
}
