//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import AVFoundation

/// Turns a stream's timed metadata into ``AudioMetadata``.
///
/// ``AudioPlayer`` calls its parser on every burst of timed metadata the engine delivers,
/// and merges the result into the track's own metadata. ``DefaultMetadataParser`` handles
/// the common AVFoundation keys, ID3 track numbering and Shoutcast artwork; write your own
/// when a station or feed puts something you need somewhere the default does not look.
///
/// Assign it through ``AudioPlayer/metadataParser``, which takes effect from the next burst:
///
///     struct StationParser: MetadataParser {
///         func metadata(from entries: [MetadataEntry]) -> AudioMetadata {
///             var metadata = DefaultMetadataParser().metadata(from: entries)
///             let raw = entries.first { $0.identifier == "icy/StreamTitle" }?.stringValue
///             if let parts = raw?.components(separatedBy: " - "), parts.count == 2 {
///                 metadata.artist = parts[0]
///                 metadata.title = parts[1]
///             }
///             return metadata
///         }
///     }
///
///     player.metadataParser = StationParser()
///
/// - Important: Whatever a parser returns only fills the gaps left by the track's own
///   ``AudioItem/metadata``. A title you set on the item outranks the stream's; see
///   ``AudioMetadata/filling(from:)``. Leave a field `nil` on the item if you want the
///   stream to supply it.
/// - Warning: ``metadata(from:)`` is called **synchronously**, on the main actor, from
///   inside the player's update for the burst. Do no blocking work in it — no file reads, no
///   network requests, no locks — or you will stall the player's bookkeeping and the UI
///   along with it.
public protocol MetadataParser: Sendable {
    /// Extracts metadata from a single burst of timed metadata entries.
    ///
    /// A burst is a slice of the stream, not the whole of it: a live station typically sends
    /// a fresh title and artist as each track changes, and sends nothing at all in between.
    ///
    /// - Parameter entries: The entries from one burst, in the order the engine delivered
    ///   them. May be empty, and may carry fields the parser does not recognise.
    /// - Returns: The fields recognised in `entries`. Leave a field `nil` rather than
    ///   guessing at it: `nil` lets the track's own metadata stand, whereas a value replaces
    ///   what the stream announced before.
    ///
    /// - Note: Each burst is merged against the track's own ``AudioItem/metadata``, not
    ///   against the previous burst. A field left `nil` therefore reverts to the value on
    ///   the item — which is `nil` unless you supplied one — rather than keeping what an
    ///   earlier burst announced.
    /// - Warning: Called synchronously on the main actor. Keep it fast and free of blocking
    ///   work.
    func metadata(from entries: [MetadataEntry]) -> AudioMetadata
}

/// The parser ``AudioPlayer`` uses unless you supply your own.
///
/// It reads, in order of preference:
///
/// - the format-independent keys AVFoundation normalises — title, artist, album name and
///   embedded artwork;
/// - ID3 track numbering, in either `number` or `number/total` form, which also supplies
///   ``AudioMetadata/trackCount``;
/// - the ID3 title-description and lead-performer frames, used only where the common keys
///   left those fields empty;
/// - `icy/StreamUrl`, the field Shoutcast stations use to carry a cover art URL.
///
/// The type is stateless, so one instance can serve any number of players.
///
/// - Note: Entries it does not recognise are dropped rather than guessed at. Wrap this in a
///   ``MetadataParser`` of your own to add a field, rather than replacing it wholesale.
public struct DefaultMetadataParser: MetadataParser {
    /// Creates a parser.
    ///
    /// The type holds no state, so instances are interchangeable and free to create.
    public init() {}

    /// Extracts metadata from a single burst of timed metadata entries.
    ///
    /// - Parameter entries: The entries from one burst. Entries matching a common key are
    ///   read first, and the rest are matched against the ID3 and Shoutcast identifiers this
    ///   parser knows.
    /// - Returns: The fields recognised in `entries`. Unrecognised entries contribute
    ///   nothing, so a burst carrying only unknown fields yields a value for which
    ///   ``AudioMetadata/isEmpty`` is `true`.
    public func metadata(from entries: [MetadataEntry]) -> AudioMetadata {
        var metadata = AudioMetadata()

        for entry in entries {
            switch entry.commonKey {
            case AVMetadataKey.commonKeyTitle.rawValue:
                metadata.title = entry.stringValue
            case AVMetadataKey.commonKeyArtist.rawValue:
                metadata.artist = entry.stringValue
            case AVMetadataKey.commonKeyAlbumName.rawValue:
                metadata.album = entry.stringValue
            case AVMetadataKey.commonKeyArtwork.rawValue:
                metadata.artwork = entry.dataValue.map(Artwork.data)
            default:
                parseIdentifier(entry, into: &metadata)
            }
        }

        return metadata
    }

    private func parseIdentifier(_ entry: MetadataEntry, into metadata: inout AudioMetadata) {
        switch entry.identifier {
        case AVMetadataIdentifier.id3MetadataTrackNumber.rawValue:
            metadata.trackNumber = entry.trackNumber
            metadata.trackCount = entry.trackCount ?? metadata.trackCount
        case AVMetadataIdentifier.id3MetadataTitleDescription.rawValue:
            metadata.title = metadata.title ?? entry.stringValue
        case AVMetadataIdentifier.id3MetadataLeadPerformer.rawValue:
            metadata.artist = metadata.artist ?? entry.stringValue
        // Shoutcast stations put the cover art URL in the stream URL field.
        case "icy/StreamUrl":
            metadata.artwork = entry.stringValue.flatMap(URL.init(string:)).map(Artwork.url)
        default:
            break
        }
    }
}

private extension MetadataEntry {
    /// ID3 writes the track number as either a bare number or `number/total`.
    var trackNumber: Int? {
        if let numberValue {
            return Int(numberValue)
        }
        return stringValue.flatMap { Int($0.split(separator: "/").first ?? "") }
    }

    var trackCount: Int? {
        guard let stringValue, stringValue.contains("/") else {
            return nil
        }
        return Int(stringValue.split(separator: "/").dropFirst().first ?? "")
    }
}
