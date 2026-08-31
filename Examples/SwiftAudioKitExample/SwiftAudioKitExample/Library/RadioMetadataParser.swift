//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation
import SwiftAudioKit

/// Shoutcast stations pack the artist and title into one field, so this splits them apart.
/// Everything else is left to the default parser.
struct RadioMetadataParser: MetadataParser {
    private let base = DefaultMetadataParser()

    func metadata(from entries: [MetadataEntry]) -> AudioMetadata {
        var metadata = base.metadata(from: entries)
        metadata.artwork = metadata.artwork.map(secured)

        guard let combined = metadata.title, let separator = combined.range(of: " - ") else {
            return metadata
        }

        metadata.artist = String(combined[..<separator.lowerBound])
        metadata.title = String(combined[separator.upperBound...])
        return metadata
    }

    /// Stations advertise their cover art over plain HTTP, which App Transport Security blocks.
    private func secured(_ artwork: Artwork) -> Artwork {
        guard case let .url(url) = artwork, url.scheme == "http" else {
            return artwork
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url.map(Artwork.url) ?? artwork
    }
}
