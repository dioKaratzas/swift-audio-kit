//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

extension AudioPlayer {
    /// Handles audio item events.
    ///
    /// - Parameters:
    ///   - producer: The event producer that generated the audio item event.
    ///   - event: The audio item event.
    func handleAudioItemEvent(from producer: EventProducer, with event: AudioItemEventProducer.AudioItemEvent) {
        updateNowPlayingInfoCenter()
    }
}
