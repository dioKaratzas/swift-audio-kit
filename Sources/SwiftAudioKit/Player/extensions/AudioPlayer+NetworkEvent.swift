//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

extension AudioPlayer {
    /// Handles network events and updates the player state accordingly.
    ///
    /// - Parameters:
    ///   - producer: The event producer that generated the network event.
    ///   - event: The network event that occurred.
    func handleNetworkEvent(from producer: EventProducer, with event: NetworkEventProducer.NetworkEvent) {
        switch event {
        case .connectionLost:
            // Handle logic when the network connection is lost
            handleConnectionLost()

        case .connectionRetrieved:
            // Handle logic when the network connection is restored
            handleConnectionRetrieved()

        case .networkChanged:
            // No action required for network change in this implementation
            break
        }
    }

    /// Handles the logic when the network connection is lost.
    private func handleConnectionLost() {
        // Early exit if the current state already indicates waiting for connection or no current item
        guard let currentItem = currentItem, !state.isWaitingForConnection else {
            return
        }

        // Check if the current item is not an offline file
        if !(currentItem.soundURLs[currentQuality]?.isOfflineURL ?? false) {
            // Save the current state to restore it later when the connection is regained
            stateWhenConnectionLost = state

            // If the player is buffering and there's no data, change the state to waiting for connection
            if player?.currentItem?.isPlaybackBufferEmpty == true {
                if state == .playing {
                    // Increase interruption count to adjust quality later
                    qualityAdjustmentEventProducer.interruptionCount += 1
                }

                // Set state to waiting for connection and begin background task to keep buffering in the background
                state = .waitingForConnection
                backgroundHandler.beginBackgroundTask()
            }
        }
    }

    /// Handles the logic when the network connection is retrieved.
    private func handleConnectionRetrieved() {
        // Early exit if connection wasn't lost during playback or if resumeAfterConnectionLoss is not enabled
        guard let lossDate = networkEventProducer.connectionLossDate,
              let stateWhenLost = stateWhenConnectionLost,
              resumeAfterConnectionLoss else {
            return
        }

        // Determine if the connection loss duration is within the allowed maximum time
        let isAllowedToRestart = lossDate.timeIntervalSinceNow < maximumConnectionLossTime
        // Check if the player was playing before the connection was lost
        let wasPlayingBeforeLoss = !stateWhenLost.isStopped

        // If allowed, attempt to resume playback or play the next item in the queue
        if isAllowedToRestart && wasPlayingBeforeLoss {
            retryOrPlayNext()
        }

        // Reset the state when connection was lost as it has been handled
        stateWhenConnectionLost = nil
    }
}
