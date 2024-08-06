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

    public init(assetURL: URL, mediaType: MPNowPlayingInfoMediaType, isLiveStream: Bool, title: String?, artist: String?, artwork: MPMediaItemArtwork?, album: String?, trackCount: NSNumber?, trackNumber: NSNumber?) {
        self.assetURL = assetURL
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.album = album
        self.trackCount = trackCount
        self.trackNumber = trackNumber
    }
}

public struct NowPlayableDynamicMetadata {
    public let rate: Float // MPNowPlayingInfoPropertyPlaybackRate
    public let position: Float // MPNowPlayingInfoPropertyElapsedPlaybackTime
    public let duration: Float // MPMediaItemPropertyPlaybackDuration
    public let currentLanguageOptions: [MPNowPlayingInfoLanguageOption] // MPNowPlayingInfoPropertyCurrentLanguageOptions
    public let availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup] // MPNowPlayingInfoPropertyAvailableLanguageOptions

    public init(rate: Float, position: Float, duration: Float, currentLanguageOptions: [MPNowPlayingInfoLanguageOption], availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]) {
        self.rate = rate
        self.position = position
        self.duration = duration
        self.currentLanguageOptions = currentLanguageOptions
        self.availableLanguageOptionGroups = availableLanguageOptionGroups
    }
}
