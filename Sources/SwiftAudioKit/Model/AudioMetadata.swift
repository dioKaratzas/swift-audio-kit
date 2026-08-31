//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// What to show for a track, with every field optional because streams send them piecemeal.
public struct AudioMetadata: Sendable, Hashable {
    /// The track's own name, which `AudioItem.displayTitle` falls back from.
    public var title: String?

    /// Who performed it, as a single string rather than a list.
    public var artist: String?

    /// The release it belongs to.
    public var album: String?

    /// Position within the album, counted from one.
    public var trackNumber: Int?

    /// How many tracks the album holds, which ID3 often sends alongside the number.
    public var trackCount: Int?

    /// Cover art, either as bytes or as a URL to fetch.
    public var artwork: Artwork?

    /// Every field defaults to `nil`, leaving it for the stream to fill.
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

    /// Nothing has been supplied or discovered yet.
    public var isEmpty: Bool {
        title == nil && artist == nil && album == nil && trackNumber == nil && trackCount == nil && artwork == nil
    }

    /// Artist and album joined by an em dash, or `nil` when neither is known.
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
