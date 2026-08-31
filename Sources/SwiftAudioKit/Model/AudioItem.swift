//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// One track in a queue: where to get it, and what to say about it.
public struct AudioItem: Sendable, Hashable, Identifiable {
    /// Fresh per item unless supplied, so two items for the same URL stay distinct.
    public let id: UUID

    /// Every stream this track can be played from.
    public var sources: AudioSources

    /// Outranks whatever the stream sends, which only fills the fields left `nil` here.
    public var metadata: AudioMetadata

    /// Takes a whole set of streams, for items that offer more than one quality.
    public init(id: UUID = UUID(), sources: AudioSources, metadata: AudioMetadata = AudioMetadata()) {
        self.id = id
        self.sources = sources
        self.metadata = metadata
    }

    /// Takes a single stream, which then answers for every quality.
    public init(
        id: UUID = UUID(),
        url: URL,
        quality: AudioQuality = .high,
        metadata: AudioMetadata = AudioMetadata()
    ) {
        self.init(id: id, sources: AudioSources(url: url, quality: quality), metadata: metadata)
    }

    /// Never empty: falls back to the file name when no title is known.
    public var displayTitle: String {
        metadata.title ?? sources.highest.url.deletingPathExtension().lastPathComponent
    }

    /// Playable without a network path, and so exempt from the connection checks.
    public var isLocal: Bool {
        sources.isLocal
    }
}
