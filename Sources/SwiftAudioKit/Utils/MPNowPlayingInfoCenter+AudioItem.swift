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
    func updateNowPlayingInfo(with item: AudioItem, duration: TimeInterval?, progression: TimeInterval?, playbackRate: Float) {
        var nowPlayingInfo = [String: Any]()

        if let title = item.title {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }
        if let artist = item.artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }
        if let album = item.album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        if let trackCount = item.trackCount {
            nowPlayingInfo[MPMediaItemPropertyAlbumTrackCount] = trackCount
        }
        if let trackNumber = item.trackNumber {
            nowPlayingInfo[MPMediaItemPropertyAlbumTrackNumber] = trackNumber
        }
        if let artwork = item.artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        if let duration = duration {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let progression = progression {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progression
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
