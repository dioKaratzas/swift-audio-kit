//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// The one or more streams an item can be played from, keyed by how good each one is.
public struct AudioSources: Sendable, Hashable {
    /// One stream picked out of the set, paired with the rung it actually came from.
    public struct Resolved: Sendable, Hashable {
        /// The stream to hand the engine.
        public let url: URL

        /// The rung this stream sits on, which may not be the rung that was asked for.
        public let quality: AudioQuality

        /// A file on disk, which plays without a network path.
        public var isLocal: Bool {
            url.isLocal
        }

        /// HLS playlists expose no audio track, so no `AVAudioMix` can be attached to them.
        public var supportsAudioProcessing: Bool {
            !url.isHLSPlaylist
        }
    }

    /// The best stream on offer, used for anything needing a single canonical URL.
    public let highest: Resolved

    private let entries: [AudioQuality: URL]

    /// Wraps a single stream, which then answers for every rung.
    public init(url: URL, quality: AudioQuality = .high) {
        entries = [quality: url]
        highest = Resolved(url: url, quality: quality)
    }

    /// `nil` only when the dictionary is empty.
    public init?(_ entries: [AudioQuality: URL]) {
        guard let best = entries.keys.max(), let url = entries[best] else {
            return nil
        }
        self.entries = entries
        highest = Resolved(url: url, quality: best)
    }

    /// The worst stream on offer, falling back to `highest` when only one exists.
    public var lowest: Resolved {
        guard let worst = entries.keys.min(), let url = entries[worst] else {
            return highest
        }
        return Resolved(url: url, quality: worst)
    }

    /// The rungs this item actually carries, which need not be all three.
    public var availableQualities: Set<AudioQuality> {
        Set(entries.keys)
    }

    /// True only when every quality is a local file, since any one of them may be chosen.
    public var isLocal: Bool {
        entries.values.allSatisfy(\.isLocal)
    }

    /// The exact rung, or `nil` where the item offers nothing at it.
    public subscript(quality: AudioQuality) -> URL? {
        entries[quality]
    }

    /// Falls back to the nearest available quality, preferring a lower one over a higher one.
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
