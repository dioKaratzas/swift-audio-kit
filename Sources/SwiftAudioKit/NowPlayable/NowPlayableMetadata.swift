/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
`NowPlayableStaticMetadata` contains static properties of a playable item that don't depend on the state of the player for their value.
*/

import Foundation
import MediaPlayer

public struct NowPlayableStaticMetadata {
    public let assetURL: URL // MPNowPlayingInfoPropertyAssetURL
    public let mediaType: MPNowPlayingInfoMediaType // MPNowPlayingInfoPropertyMediaType
    public let isLiveStream: Bool // MPNowPlayingInfoPropertyIsLiveStream
    public let title: String? // MPMediaItemPropertyTitle
    public let artist: String? // MPMediaItemPropertyArtist
    public let artwork: MPMediaItemArtwork? // MPMediaItemPropertyArtwork
    public let album: String? // MPMediaItemPropertyAlbumTitle
    public let trackCount: NSNumber? // MPMediaItemPropertyAlbumTrackCount
    public let trackNumber: NSNumber? // MPMediaItemPropertyAlbumTrackNumber
}

public struct NowPlayableDynamicMetadata {
    public let rate: Float                     // MPNowPlayingInfoPropertyPlaybackRate
    public let position: Float                 // MPNowPlayingInfoPropertyElapsedPlaybackTime
    public let duration: Float                 // MPMediaItemPropertyPlaybackDuration
    public let currentLanguageOptions: [MPNowPlayingInfoLanguageOption] // MPNowPlayingInfoPropertyCurrentLanguageOptions
    public let availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup] // MPNowPlayingInfoPropertyAvailableLanguageOptions
}
