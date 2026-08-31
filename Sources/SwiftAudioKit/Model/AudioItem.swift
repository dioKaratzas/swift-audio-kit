//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

public struct AudioItem: Sendable, Hashable, Identifiable {
    public struct ID: Sendable, Hashable {
        public let rawValue: UUID

        public init(rawValue: UUID = UUID()) {
            self.rawValue = rawValue
        }
    }

    public let id: ID
    public var sources: AudioSources
    public var metadata: AudioMetadata

    public init(id: ID = ID(), sources: AudioSources, metadata: AudioMetadata = AudioMetadata()) {
        self.id = id
        self.sources = sources
        self.metadata = metadata
    }

    public init(
        id: ID = ID(),
        url: URL,
        quality: AudioQuality = .high,
        metadata: AudioMetadata = AudioMetadata()
    ) {
        self.init(id: id, sources: AudioSources(url: url, quality: quality), metadata: metadata)
    }

    public var displayTitle: String {
        metadata.title ?? sources.highest.url.deletingPathExtension().lastPathComponent
    }

    public var isLocal: Bool {
        sources.isLocal
    }
}
