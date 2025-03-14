//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Combine
import MediaPlayer
import AVFoundation

#if os(iOS) || os(tvOS)
    import UIKit

    public typealias SystemImage = UIImage
#else
    import Cocoa

    public typealias SystemImage = NSImage
#endif

// MARK: - AudioQuality

/// `AudioQuality` differentiates qualities for audio.
public enum AudioQuality: Int {
    case low = 0
    case medium = 1
    case high = 2
}

// MARK: - AudioItemURL

/// `AudioItemURL` contains information about an Item URL such as its quality.
public struct AudioItemURL {
    /// The quality of the stream.
    public let quality: AudioQuality

    /// The URL of the stream.
    public let url: URL

    /// Initializes an AudioItemURL.
    ///
    /// - Parameters:
    ///   - quality: The quality of the stream.
    ///   - url: The URL of the stream.
    public init?(quality: AudioQuality, url: URL?) {
        guard let url else {
            return nil
        }
        self.quality = quality
        self.url = url
    }
}

// MARK: - AudioItem

/// An `AudioItem` instance contains every piece of information needed for an `AudioPlayer` to play.
///
/// URLs can be remote or local.
open class AudioItem: ObservableObject {
    /// Returns the available qualities.
    public let soundURLs: [AudioQuality: URL]

    // MARK: Initialization

    /// Initializes an AudioItem. Fails if all URLs are nil.
    ///
    /// - Parameters:
    ///   - highQualitySoundURL: The URL for the high-quality sound.
    ///   - mediumQualitySoundURL: The URL for the medium-quality sound.
    ///   - lowQualitySoundURL: The URL for the low-quality sound.
    public convenience init?(
        highQualitySoundURL: URL? = nil,
        mediumQualitySoundURL: URL? = nil,
        lowQualitySoundURL: URL? = nil
    ) {
        var URLs = [AudioQuality: URL]()
        if let highURL = highQualitySoundURL {
            URLs[.high] = highURL
        }
        if let mediumURL = mediumQualitySoundURL {
            URLs[.medium] = mediumURL
        }
        if let lowURL = lowQualitySoundURL {
            URLs[.low] = lowURL
        }
        self.init(soundURLs: URLs)
    }

    /// Initializes an `AudioItem`.
    ///
    /// - Parameter soundURLs: The URLs of the sound associated with its quality wrapped in a `Dictionary`.
    public init?(soundURLs: [AudioQuality: URL]) {
        self.soundURLs = soundURLs

        if soundURLs.isEmpty {
            return nil
        }
    }

    // MARK: Quality selection

    /// Returns the highest quality URL found, or nil if no URLs are available.
    open var highestQualityURL: AudioItemURL {
        return AudioItemURL(quality: .high, url: soundURLs[.high]) ??
            AudioItemURL(quality: .medium, url: soundURLs[.medium]) ??
            AudioItemURL(quality: .low, url: soundURLs[.low])!
    }

    /// Returns the medium quality URL found, or nil if no URLs are available.
    open var mediumQualityURL: AudioItemURL {
        return AudioItemURL(quality: .medium, url: soundURLs[.medium]) ??
            AudioItemURL(quality: .low, url: soundURLs[.low]) ??
            AudioItemURL(quality: .high, url: soundURLs[.high])!
    }

    /// Returns the lowest quality URL found, or nil if no URLs are available.
    open var lowestQualityURL: AudioItemURL {
        return AudioItemURL(quality: .low, url: soundURLs[.low]) ??
            AudioItemURL(quality: .medium, url: soundURLs[.medium]) ??
            AudioItemURL(quality: .high, url: soundURLs[.high])!
    }

    /// Returns a URL that best fits a given quality.
    ///
    /// - Parameter quality: The quality for the requested URL.
    /// - Returns: The URL that best fits the given quality.
    func url(for quality: AudioQuality) -> AudioItemURL {
        switch quality {
        case .high:
            return highestQualityURL
        case .medium:
            return mediumQualityURL
        default:
            return lowestQualityURL
        }
    }

    // MARK: Additional properties

    /// The artist of the item.
    @Published open var artist: String?

    /// The title of the item.
    @Published open var title: String?

    /// The album of the item.
    @Published open var album: String?

    /// The track count of the item's album.
    @Published open var trackCount: NSNumber?

    /// The track number of the item in its album.
    @Published open var trackNumber: NSNumber?

    /// The artwork image of the item.
    open var artworkImage: SystemImage? {
        get {
            return artwork?.image(at: imageSize ?? CGSize(width: 512, height: 512))
        }
        set {
            imageSize = newValue?.size
            if let newImage = newValue {
                artwork = MPMediaItemArtwork(boundsSize: newImage.size) { _ in newImage }
            } else {
                artwork = nil
            }
        }
    }

    @Published open var artwork: MPMediaItemArtwork?
    private var imageSize: CGSize?

    // MARK: Metadata

    /// Parses the metadata coming from the stream/file specified in the URLs. The default behavior is to set values
    /// for every property that is nil. Customization is available through subclassing.
    ///
    /// - Parameter items: The metadata items.
    open func parseMetadata(_ items: [AVMetadataItem]) {
        for item in items {
            if let commonKey = item.commonKey {
                switch commonKey {
                case AVMetadataKey.commonKeyTitle:
                    title = item.value as? String
                case AVMetadataKey.commonKeyArtist:
                    artist = item.value as? String
                case AVMetadataKey.commonKeyAlbumName:
                    album = item.value as? String
                case AVMetadataKey.id3MetadataKeyTrackNumber:
                    trackNumber = item.value as? NSNumber
                case AVMetadataKey.commonKeyArtwork:
                    artworkImage = (item.value as? Data).flatMap { SystemImage(data: $0) }
                default:
                    break
                }
            }
        }
    }
}

extension AudioItem: Equatable {
    public static func == (lhs: AudioItem, rhs: AudioItem) -> Bool {
        return lhs === rhs
    }
}
