//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// The one or more streams an item can be played from, keyed by how good each one is.
///
/// Describe a track that exists at several bitrates with this, and the player picks a stream
/// each time it loads the track, matching the current ``AudioPlayer/quality``. A track that
/// exists at one bitrate needs nothing special: ``AudioItem/init(id:url:quality:metadata:)``
/// builds a single-entry value for you.
///
///     let sources = AudioSources([
///         .low: URL(string: "https://example.com/stream-64.mp3")!,
///         .high: URL(string: "https://example.com/stream-256.mp3")!
///     ])
///     let item = sources.map { AudioItem(sources: $0) }
///
/// A value of this type always holds at least one stream: the failable initialiser is the
/// only way to build an empty mapping, and it refuses. Every accessor therefore returns a
/// real stream rather than an optional, and none of them can trap.
public struct AudioSources: Sendable, Hashable {
    /// One stream picked out of the set, paired with the rung it actually came from.
    ///
    /// Returned by ``AudioSources/resolve(preferring:)`` and held by ``AudioSources/highest``
    /// and ``AudioSources/lowest``. The ``quality`` it reports is the rung the URL is
    /// registered under, which is not necessarily the rung that was asked for.
    public struct Resolved: Sendable, Hashable {
        /// The stream to hand the engine.
        public let url: URL

        /// The rung this stream sits on.
        ///
        /// - Important: This may differ from the quality passed to
        ///   ``AudioSources/resolve(preferring:)``, because an item need not offer every
        ///   rung. Compare against it rather than assuming the request was honoured.
        public let quality: AudioQuality

        /// Whether the stream is a file the device already holds.
        ///
        /// Local streams play without a network path, so an item made only of them is exempt
        /// from the player's connection checks. File URLs count, and so do the
        /// `ipod-library` scheme and anything served from `localhost` or `127.0.0.1`.
        public var isLocal: Bool {
            url.isLocal
        }
    }

    /// The best stream on offer.
    ///
    /// Used wherever a single canonical URL is needed regardless of the rung in play — the
    /// asset URL published to the Now Playing information, and the file name
    /// ``AudioItem/displayTitle`` falls back to. Equal to ``lowest`` when the item offers
    /// one stream.
    public let highest: Resolved

    private let entries: [AudioQuality: URL]

    /// Creates a set holding a single stream.
    ///
    /// Because it is the only entry, this stream answers for every rung:
    /// ``resolve(preferring:)`` returns it whatever is asked for, and
    /// ``AudioPlayer/setQuality(_:)`` has no alternative to switch to.
    ///
    /// - Parameters:
    ///   - url: The stream to play.
    ///   - quality: The rung to register it under. Defaults to ``AudioQuality/high``. The
    ///     value shows up in ``Resolved/quality`` and in ``availableQualities``, so pick the
    ///     rung that honestly describes the stream.
    public init(url: URL, quality: AudioQuality = .high) {
        entries = [quality: url]
        highest = Resolved(url: url, quality: quality)
    }

    /// Creates a set from a quality-to-URL mapping.
    ///
    /// Rungs may be left out. An item that offers only ``AudioQuality/low`` and
    /// ``AudioQuality/high`` is perfectly ordinary, and ``resolve(preferring:)`` falls back
    /// to the nearest rung present.
    ///
    /// - Parameter entries: The streams to offer, keyed by the rung each one sits on. A
    ///   later duplicate key wins, as with any dictionary literal.
    /// - Returns: `nil` when `entries` is empty, because an item with no stream cannot be
    ///   played. Otherwise a value whose ``highest`` is the URL at the largest key present.
    public init?(_ entries: [AudioQuality: URL]) {
        guard let best = entries.keys.max(), let url = entries[best] else {
            return nil
        }
        self.entries = entries
        highest = Resolved(url: url, quality: best)
    }

    /// The smallest stream on offer.
    ///
    /// Equal to ``highest`` when the item offers one stream, so this is always safe to read.
    public var lowest: Resolved {
        guard let worst = entries.keys.min(), let url = entries[worst] else {
            return highest
        }
        return Resolved(url: url, quality: worst)
    }

    /// The rungs this item actually carries.
    ///
    /// Never empty, and need not contain all three rungs. Use it to decide whether offering
    /// a quality picker is worth it: a set of one means there is nothing to choose between.
    public var availableQualities: Set<AudioQuality> {
        Set(entries.keys)
    }

    /// Whether every stream in the set is playable without a network path.
    ///
    /// - Important: This is `true` only when *all* streams are local, not merely one of
    ///   them, because the player may resolve to any of them. A set mixing a local file with
    ///   a remote fallback is treated as remote and is subject to the connection checks.
    public var isLocal: Bool {
        entries.values.allSatisfy(\.isLocal)
    }

    /// Returns the stream registered at an exact rung, without falling back.
    ///
    /// - Parameter quality: The rung to look up.
    /// - Returns: The URL at that exact rung, or `nil` when the item offers nothing there.
    ///   Use ``resolve(preferring:)`` when you want the nearest stream instead of `nil`.
    public subscript(quality: AudioQuality) -> URL? {
        entries[quality]
    }

    /// Returns the stream closest to a requested quality.
    ///
    /// This is what the player calls each time it loads a track. When the exact rung is
    /// missing it picks the nearest one the item has, and breaks a tie by preferring the
    /// *lower* neighbour: asking for ``AudioQuality/medium`` on an item offering only `low`
    /// and `high` resolves to `low`. Erring downwards keeps a constrained link from being
    /// handed a larger stream than it asked for.
    ///
    /// - Parameter quality: The rung to aim for.
    /// - Returns: The chosen stream paired with the rung it actually came from, which may
    ///   differ from `quality`. Never `nil` and never a trap: the set always holds at least
    ///   one stream, so there is always something to fall back to.
    public func resolve(preferring quality: AudioQuality) -> Resolved {
        guard let match = entries.keys.min(by: { distance(from: $0, to: quality) < distance(from: $1, to: quality) }),
              let url = entries[match] else {
            return highest
        }
        return Resolved(url: url, quality: match)
    }

    private func distance(from candidate: AudioQuality, to target: AudioQuality) -> (Int, Int) {
        (abs(candidate.rawValue - target.rawValue), candidate > target ? 1 : 0)
    }
}
