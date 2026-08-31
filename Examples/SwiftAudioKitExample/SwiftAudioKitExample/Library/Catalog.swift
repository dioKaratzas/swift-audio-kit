//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation
import SwiftAudioKit

/// Radio Paradise is used throughout because it reports itself as live and sends real
/// per-track metadata, including cover art.
enum Catalog {
    /// One station published at three bitrates, which is what the quality system is for.
    static let mainMix = AudioItem(
        sources: AudioSources([
            .low: url("mp3-128"),
            .medium: url("mp3-192"),
            .high: url("aac-320")
        ])!,
        metadata: AudioMetadata(album: "Main Mix")
    )

    static let mellowMix = AudioItem(
        url: url("mellow-192"),
        metadata: AudioMetadata(album: "Mellow Mix")
    )

    static let rockMix = AudioItem(
        url: url("rock-192"),
        metadata: AudioMetadata(album: "Rock Mix")
    )

    static let globalMix = AudioItem(
        url: url("global-192"),
        metadata: AudioMetadata(album: "Global Mix")
    )

    static let all: [AudioItem] = [mainMix, mellowMix, rockMix, globalMix]

    static func station(for item: AudioItem) -> String {
        item.metadata.album ?? "Radio Paradise"
    }

    private static func url(_ mount: String) -> URL {
        URL(string: "https://stream.radioparadise.com/\(mount)")!
    }
}
