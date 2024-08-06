//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import MediaPlayer

extension MPNowPlayingInfoCenter {
    /// Updates the MPNowPlayingInfoCenter with the latest information on a `AudioItem`.
    ///
    /// - Parameters:
    ///   - item: The item that is currently played.
    ///   - duration: The item's duration.
    ///   - progression: The current progression.
    ///   - playbackRate: The current playback rate.
    func ap_update(with item: AudioItem, duration: TimeInterval?, progression: TimeInterval?, playbackRate: Float) {
        var info = [String: Any]()
        if let title = item.title {
            info[MPMediaItemPropertyTitle] = title
        }
        if let artist = item.artist {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let album = item.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let trackCount = item.trackCount {
            info[MPMediaItemPropertyAlbumTrackCount] = trackCount
        }
        if let trackNumber = item.trackNumber {
            info[MPMediaItemPropertyAlbumTrackNumber] = trackNumber
        }
        if let artwork = item.artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        if let duration = duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let progression = progression {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progression
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate

        nowPlayingInfo = info
    }
}
