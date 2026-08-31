//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// One track in a queue: where to get it, and what to say about it.
///
/// An item pairs the stream or streams a track can be played from with whatever you already
/// know about it. Items are identified by ``id`` rather than by URL, so the same URL can
/// appear in a queue more than once as long as each copy carries its own identifier.
public struct AudioItem: Sendable, Hashable, Identifiable {
    /// The value that identifies this track everywhere the player refers to it.
    ///
    /// ``PlaybackQueue`` matches on this: appending an item whose identifier is already
    /// queued does nothing, and ``AudioPlayer/skippedItems`` addresses tracks by it.
    public let id: UUID

    /// Every stream this track can be played from, keyed by the quality rung it sits on.
    ///
    /// The player picks one each time it loads the track, using
    /// ``AudioSources/resolve(preferring:)`` against the current ``AudioPlayer/quality``.
    public var sources: AudioSources

    /// What you already know about the track.
    ///
    /// These values outrank whatever the stream announces: a burst of timed metadata fills
    /// only the fields left `nil` here. See ``AudioMetadata/filling(from:)``.
    public var metadata: AudioMetadata

    /// Creates an item that can be played from more than one stream.
    ///
    /// - Parameters:
    ///   - id: The identity the queue matches on. Defaults to a fresh `UUID`, which keeps two
    ///     items for the same URL distinct so both can be queued.
    ///   - sources: The streams this track offers, keyed by quality.
    ///   - metadata: What you already know about the track. Fields left `nil` are the only
    ///     ones the stream is allowed to fill. Defaults to an empty ``AudioMetadata``.
    public init(id: UUID = UUID(), sources: AudioSources, metadata: AudioMetadata = AudioMetadata()) {
        self.id = id
        self.sources = sources
        self.metadata = metadata
    }

    /// Creates an item that can be played from a single stream.
    ///
    /// Because the item offers one stream, that stream answers for every quality rung and
    /// ``AudioPlayer/setQuality(_:)`` has no alternative to switch to.
    ///
    /// - Parameters:
    ///   - id: The identity the queue matches on. Defaults to a fresh `UUID`.
    ///   - url: The stream to play. Local file URLs are exempt from the player's connection
    ///     checks; see ``isLocal``.
    ///   - quality: The rung to record the stream under. Defaults to ``AudioQuality/high``.
    ///   - metadata: What you already know about the track. Defaults to an empty
    ///     ``AudioMetadata``.
    public init(
        id: UUID = UUID(),
        url: URL,
        quality: AudioQuality = .high,
        metadata: AudioMetadata = AudioMetadata()
    ) {
        self.init(id: id, sources: AudioSources(url: url, quality: quality), metadata: metadata)
    }

    /// A title that is always safe to show in a list or on a lock screen.
    ///
    /// Uses ``AudioMetadata/title`` when one is known, and otherwise the file name of
    /// ``AudioSources/highest`` with its extension removed. Never empty.
    public var displayTitle: String {
        metadata.title ?? sources.highest.url.deletingPathExtension().lastPathComponent
    }

    /// Whether the track can be played without a network path.
    ///
    /// Local items never enter ``PlaybackState/waitingForConnection(_:)`` and are never
    /// failed with ``AudioPlayerError/connectionLost(after:)``.
    ///
    /// - Important: `true` only when *every* stream in ``sources`` is local, since the player
    ///   may resolve to any of them. File URLs count as local, and so do the `ipod-library`
    ///   scheme and streams served from `localhost` or `127.0.0.1`.
    public var isLocal: Bool {
        sources.isLocal
    }
}
