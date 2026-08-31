//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public struct AudioMetadata: Sendable, Hashable {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var trackNumber: Int?
    public var trackCount: Int?
    public var artwork: Artwork?

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        trackNumber: Int? = nil,
        trackCount: Int? = nil,
        artwork: Artwork? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.trackCount = trackCount
        self.artwork = artwork
    }

    public var isEmpty: Bool {
        title == nil && artist == nil && album == nil && trackNumber == nil && trackCount == nil && artwork == nil
    }

    public var subtitle: String? {
        [artist, album].compactMap(\.self).joined(separator: " — ").nilWhenEmpty
    }

    /// Fills only the fields that are still `nil`, so caller-supplied values outrank stream metadata.
    public func filling(from other: AudioMetadata) -> AudioMetadata {
        AudioMetadata(
            title: title ?? other.title,
            artist: artist ?? other.artist,
            album: album ?? other.album,
            trackNumber: trackNumber ?? other.trackNumber,
            trackCount: trackCount ?? other.trackCount,
            artwork: artwork ?? other.artwork
        )
    }
}

private extension String {
    var nilWhenEmpty: String? {
        isEmpty ? nil : self
    }
}
