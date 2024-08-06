//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

extension AudioPlayer {
    /// Handles seek events.
    ///
    /// - Parameters:
    ///   - producer: The event producer that generated the seek event.
    ///   - event: The seek event.
    func handleSeekEvent(from producer: EventProducer, with event: SeekEventProducer.SeekEvent) {
        guard let currentItemProgression = currentItemProgression,
            case .changeTime(_, let delta) = seekingBehavior else { return }

        switch event {
        case .seekBackward:
            seek(to: currentItemProgression - delta)

        case .seekForward:
            seek(to: currentItemProgression + delta)
        }
    }
}
