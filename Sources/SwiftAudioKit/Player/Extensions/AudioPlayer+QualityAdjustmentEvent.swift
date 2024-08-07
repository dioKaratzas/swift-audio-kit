//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import AVFoundation

extension AudioPlayer {
    /// Handles quality adjustment events and adjusts the playback quality accordingly.
    ///
    /// - Parameters:
    ///   - producer: The event producer that generated the quality adjustment event.
    ///   - event: The quality adjustment event indicating whether to increase or decrease quality.
    func handleQualityEvent(
        from producer: EventProducer,
        with event: QualityAdjustmentEventProducer.QualityAdjustmentEvent
    ) {
        // Exit early if automatic quality adjustment is disabled.
        guard adjustQualityAutomatically else {
            return
        }

        switch event {
        case .goDown:
            adjustQuality(down: true)
        case .goUp:
            adjustQuality(down: false)
        }
    }

    /// Adjusts the stream quality based on the event.
    ///
    /// - Parameter down: A boolean indicating whether the quality should be lowered (`true`) or raised (`false`).
    private func adjustQuality(down: Bool) {
        let qualityChange = down ? -1 : 1
        guard let newQuality = AudioQuality(rawValue: currentQuality.rawValue + qualityChange) else {
            return
        }
        changeQuality(to: newQuality)
    }

    /// Changes the quality of the current item stream if possible.
    ///
    /// - Parameter newQuality: The new desired quality level for playback.
    private func changeQuality(to newQuality: AudioQuality) {
        guard let url = currentItem?.soundURLs[newQuality] else {
            return
        }

        let currentProgression = currentItemProgression
        let newItem = AVPlayerItem(url: url)
        updatePlayerItemForBufferingStrategy(newItem)

        qualityIsBeingChanged = true
        player?.replaceCurrentItem(with: newItem)
        if let progression = currentProgression {
            // Seek to the last known progression after changing quality, if applicable.
            player?.seek(to: CMTime(timeInterval: progression))
        }
        qualityIsBeingChanged = false

        currentQuality = newQuality
    }
}
