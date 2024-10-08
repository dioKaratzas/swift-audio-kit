//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// Represents an event that can occur within the system.
protocol Event {}

/// A protocol that listens to events generated by an `EventProducer`.
/// Implementers of this protocol should handle events when they are notified.
protocol EventListener: AnyObject {
    /// Called when an event occurs.
    ///
    /// - Parameters:
    ///   - event: The event that occurred.
    ///   - eventProducer: The producer that generated the event.
    func onEvent(_ event: Event, generatedBy eventProducer: EventProducer)
}

/// A protocol for producing events over time. Conforming types are responsible
/// for generating events and notifying their listeners.
protocol EventProducer: AnyObject {
    /// The listener that will be alerted when a new event occurs.
    var eventListener: EventListener? { get set }

    /// Starts the production of events. Implementers should ensure that events
    /// are being generated and delivered to the `eventListener`.
    func startProducingEvents()

    /// Stops the production of events. Implementers should ensure that no further
    /// events are generated or delivered to the `eventListener`.
    func stopProducingEvents()
}
