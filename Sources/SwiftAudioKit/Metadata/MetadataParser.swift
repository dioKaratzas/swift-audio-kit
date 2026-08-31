//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import AVFoundation

public protocol MetadataParser: Sendable {
    func metadata(from entries: [MetadataEntry]) -> AudioMetadata
}

public struct DefaultMetadataParser: MetadataParser {
    public init() {}

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
