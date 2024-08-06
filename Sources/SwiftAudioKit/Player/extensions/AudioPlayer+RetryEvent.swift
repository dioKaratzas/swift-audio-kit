//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

extension AudioPlayer {
    /// Handles retry events.
    ///
    /// - Parameters:
    ///   - producer: The event producer that generated the retry event.
    ///   - event: The retry event.
    func handleRetryEvent(from producer: EventProducer, with event: RetryEventProducer.RetryEvent) {
        switch event {
        case .retryAvailable:
            retryOrPlayNext()

        case .retryFailed:
            state = .failed(.maximumRetryCountHit)
            producer.stopProducingEvents()
        }
    }
}
