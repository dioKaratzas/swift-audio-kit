//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Network

actor NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "swiftaudiokit.network", qos: .utility)
    private var isRunning = false

    /// Emits the current path first, then every change, until the stream is dropped.
    func statuses() -> AsyncStream<NetworkStatus> {
        let (stream, continuation) = AsyncStream<NetworkStatus>.makeStream(
            bufferingPolicy: .bufferingNewest(8)
        )

        monitor.pathUpdateHandler = { path in
            let status = NetworkStatus(path)
            Log.network.debug(
                "path \(String(describing: status.reachability), privacy: .public) expensive \(status.isExpensive)"
            )
            continuation.yield(status)
        }
        continuation.onTermination = { [monitor] _ in
            monitor.cancel()
        }

        if !isRunning {
            isRunning = true
            monitor.start(queue: queue)
        }
        return stream
    }

    func cancel() {
        guard isRunning else {
            return
        }
        isRunning = false
        monitor.cancel()
    }
}

extension NetworkStatus {
    init(_ path: NWPath) {
        self.init(
            reachability: Reachability(path.status),
            interface: Interface(path),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }
}

private extension NetworkStatus.Reachability {
    init(_ status: NWPath.Status) {
        switch status {
        case .satisfied: self = .available
        case .unsatisfied: self = .unavailable
        // A route that has yet to be brought up is not a report of no route.
        case .requiresConnection: self = .unknown
        @unknown default: self = .unknown
        }
    }
}

private extension NetworkStatus.Interface {
    init?(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            self = .wifi
        } else if path.usesInterfaceType(.cellular) {
            self = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            self = .wired
        } else if path.status == .satisfied {
            self = .other
        } else {
            return nil
        }
    }
}
