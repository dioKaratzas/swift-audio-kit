//
//  SwiftAudioKitExample
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation
import SwiftAudioKit

enum Catalog {
    /// One stream published at three bitrates, which is what the quality system is for.
    static let grooveSalad = AudioItem(
        sources: AudioSources([
            .low: url("groovesalad-64-aac"),
            .medium: url("groovesalad-128-mp3"),
            .high: url("groovesalad-256-mp3")
        ])!,
        metadata: AudioMetadata(title: "Groove Salad", artist: "SomaFM", album: "Ambient")
    )

    static let droneZone = AudioItem(
        url: url("dronezone-128-mp3"),
        metadata: AudioMetadata(title: "Drone Zone", artist: "SomaFM", album: "Atmospheric")
    )

    static let deepSpaceOne = AudioItem(
        url: url("deepspaceone-128-mp3"),
        metadata: AudioMetadata(title: "Deep Space One", artist: "SomaFM", album: "Ambient")
    )

    static let indiePop = AudioItem(
        url: url("indiepop-128-mp3"),
        metadata: AudioMetadata(title: "Indie Pop Rocks", artist: "SomaFM", album: "Indie")
    )

    static let all: [AudioItem] = [grooveSalad, droneZone, deepSpaceOne, indiePop]

    private static func url(_ mount: String) -> URL {
        URL(string: "https://ice1.somafm.com/\(mount)")!
    }
}
