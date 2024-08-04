//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation
import Combine

/// A `NetworkEventProducer` generates `NetworkEvent`s when there are changes in the network.
class NetworkEventProducer: EventProducer {
    /// A `NetworkEvent` is an event generated by a network monitor.
    ///
    /// - networkChanged: The network changed.
    /// - connectionRetrieved: The connection is now up.
    /// - connectionLost: The connection has been lost.
    enum NetworkEvent: Event {
        case networkChanged
        case connectionRetrieved
        case connectionLost
    }

    /// The reachability to work with.
    let reachability: Reachability

    /// The date at which the connection was lost.
    private(set) var connectionLossDate: Date?

    /// The listener that will be alerted when a new event occurs.
    weak var eventListener: EventListener?

    /// A boolean value indicating whether we're currently listening to events.
    private(set) var isListening = false

    /// The last status received.
    private var lastStatus: Reachability.NetworkStatus

    /// Combine cancellables for managing subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Initializes a `NetworkEventProducer` with reachability.
    ///
    /// - Parameter reachability: The reachability to work with.
    init(reachability: Reachability) {
        self.reachability = reachability
        self.lastStatus = reachability.currentReachabilityStatus

        if lastStatus == .notReachable {
            self.connectionLossDate = Date()
        }
    }

    /// Stops producing events on deinitialization.
    deinit {
        stopProducingEvents()
    }

    /// Starts listening to the network events.
    func startProducingEvents() {
        guard !isListening else { return }

        // Update status and start notifier
        lastStatus = reachability.currentReachabilityStatus
        isListening = true

        NotificationCenter.default.publisher(for: .ReachabilityChanged, object: reachability)
            .sink { [weak self] _ in
                self?.handleReachabilityChange()
            }
            .store(in: &cancellables)

        reachability.startNotifier()
    }

    /// Stops listening to the network events.
    func stopProducingEvents() {
        guard isListening else { return }

        // Stop listening and clean up
        isListening = false
        reachability.stopNotifier()
        cancellables.removeAll()
    }

    /// Handles the reachability status change event.
    private func handleReachabilityChange() {
        let newStatus = reachability.currentReachabilityStatus
        if newStatus != lastStatus {
            if newStatus == .notReachable {
                connectionLossDate = Date()
                eventListener?.onEvent(NetworkEvent.connectionLost, generatedBy: self)
            } else if lastStatus == .notReachable {
                connectionLossDate = nil
                eventListener?.onEvent(NetworkEvent.connectionRetrieved, generatedBy: self)
            } else {
                eventListener?.onEvent(NetworkEvent.networkChanged, generatedBy: self)
            }
            lastStatus = newStatus
        }
    }
}
