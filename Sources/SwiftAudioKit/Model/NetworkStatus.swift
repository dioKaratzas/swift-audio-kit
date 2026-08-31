//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public struct NetworkStatus: Sendable, Hashable {
    public enum Reachability: Sendable, Hashable {
        case unknown
        case unavailable
        case available
    }

    public enum Interface: Sendable, Hashable {
        case wifi
        case cellular
        case wired
        case other
    }

    public var reachability: Reachability
    public var interface: Interface?
    public var isExpensive: Bool
    public var isConstrained: Bool

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

    public static let unknown = NetworkStatus()
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
