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
        if setNowPlayingMetadata, let currentItem {
            let isLiveStream = !currentItem.highestQualityURL.url.isOfflineURL
            let metadata = NowPlayableStaticMetadata(
                assetURL: currentItem.highestQualityURL.url,
                mediaType: .audio,
                isLiveStream: isLiveStream,
                title: currentItem.title,
                artist: currentItem.artist,
                artwork: currentItem.artwork,
                album: currentItem.album,
                trackCount: currentItem.trackCount,
                trackNumber: currentItem.trackNumber
            )
            nowPlayableService?.handleNowPlayableItemChange(metadata: metadata)
        }
    }
}
