//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// What to show for a track, with every field optional because streams send them piecemeal.
///
/// Attach one to an ``AudioItem`` to say what you already know, and read
/// ``AudioPlayer/metadata`` to get that same information with anything the stream announced
/// merged in. The player publishes the merged value; the item keeps yours.
public struct AudioMetadata: Sendable, Hashable {
    /// The track's own name.
    ///
    /// ``AudioItem/displayTitle`` falls back to the stream's file name when this is `nil`.
    public var title: String?

    /// Who performed the track, as a single string rather than a list.
    public var artist: String?

    /// The release the track belongs to.
    public var album: String?

    /// The track's position within its album, counted from one.
    public var trackNumber: Int?

    /// How many tracks the album holds.
    ///
    /// ID3 writes this alongside ``trackNumber`` in a single `number/total` field, so the two
    /// usually arrive together or not at all.
    public var trackCount: Int?

    /// Cover art, either as bytes or as a URL to fetch.
    public var artwork: Artwork?

    /// Creates metadata from the fields you know.
    ///
    /// - Parameters:
    ///   - title: The track's name, or `nil` to let the stream supply it.
    ///   - artist: The performer, or `nil` to let the stream supply it.
    ///   - album: The release, or `nil` to let the stream supply it.
    ///   - trackNumber: Position within the album, counted from one, or `nil`.
    ///   - trackCount: How many tracks the album holds, or `nil`.
    ///   - artwork: Cover art, or `nil` to let the stream supply it.
    ///
    /// - Important: `nil` is what makes a field eligible to be filled from the stream.
    ///   Supplying a value pins it; see ``filling(from:)``.
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

    /// Whether nothing has been supplied or discovered yet.
    ///
    /// True only when all six fields are `nil`.
    public var isEmpty: Bool {
        title == nil && artist == nil && album == nil && trackNumber == nil && trackCount == nil && artwork == nil
    }

    /// A single line combining ``artist`` and ``album``, ready to show under a title.
    ///
    /// The two are joined by an em dash. When only one is known that one is returned alone,
    /// and when neither is the result is `nil` rather than an empty string.
    public var subtitle: String? {
        [artist, album].compactMap(\.self).joined(separator: " — ").nilWhenEmpty
    }

    /// Returns a copy of this metadata with its empty fields filled in from another value.
    ///
    /// This is how the player merges what a stream announces into what you supplied. The
    /// receiver holds your values and `other` the discovered ones, so a title you set on an
    /// ``AudioItem`` survives a station that announces a different one.
    ///
    /// - Parameter other: The metadata to draw from. Its values are used only where the
    ///   receiver has none, so the argument never overwrites anything.
    /// - Returns: A new value whose fields are the receiver's, each `nil` field replaced by
    ///   the matching field of `other`. Equal to the receiver when no field is `nil`, and to
    ///   `other` when the receiver ``isEmpty``.
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
