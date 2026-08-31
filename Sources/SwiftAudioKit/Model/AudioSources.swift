//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

public struct AudioSources: Sendable, Hashable {
    public struct Resolved: Sendable, Hashable {
        public let url: URL
        public let quality: AudioQuality

        public var isLocal: Bool {
            url.isLocal
        }

        /// HLS playlists expose no audio track, so no `AVAudioMix` can be attached to them.
        public var supportsAudioProcessing: Bool {
            !url.isHLSPlaylist
        }
    }

    public let highest: Resolved

    private let entries: [AudioQuality: URL]

    public init(url: URL, quality: AudioQuality = .high) {
        entries = [quality: url]
        highest = Resolved(url: url, quality: quality)
    }

    public init?(_ entries: [AudioQuality: URL]) {
        guard let best = entries.keys.max(), let url = entries[best] else {
            return nil
        }
        self.entries = entries
        highest = Resolved(url: url, quality: best)
    }

    public var lowest: Resolved {
        guard let worst = entries.keys.min(), let url = entries[worst] else {
            return highest
        }
        return Resolved(url: url, quality: worst)
    }

    public var availableQualities: Set<AudioQuality> {
        Set(entries.keys)
    }

    public var isLocal: Bool {
        entries.values.allSatisfy(\.isLocal)
    }

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
