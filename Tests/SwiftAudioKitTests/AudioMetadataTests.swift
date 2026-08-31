//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Audio metadata")
struct AudioMetadataTests {
    @Test(
        "Emptiness tracks every field",
        arguments: [
            (AudioMetadata(), true),
            (AudioMetadata(title: "Anthem"), false),
            (AudioMetadata(artist: "Someone"), false),
            (AudioMetadata(album: "Debut"), false),
            (AudioMetadata(trackNumber: 3), false),
            (AudioMetadata(trackCount: 12), false)
        ]
    )
    func emptiness(_ metadata: AudioMetadata, _ isEmpty: Bool) {
        #expect(metadata.isEmpty == isEmpty)
    }

    @Test("Filling keeps existing values and adopts missing ones")
    func fillingPrefersExistingValues() {
        let caller = AudioMetadata(title: "Caller title", trackNumber: 1)
        let stream = AudioMetadata(title: "Stream title", artist: "Stream artist", trackCount: 12)

        let merged = caller.filling(from: stream)

        #expect(merged.title == "Caller title")
        #expect(merged.trackNumber == 1)
        #expect(merged.artist == "Stream artist")
        #expect(merged.trackCount == 12)
        #expect(merged.album == nil)
    }

    @Test("Filling from empty metadata changes nothing")
    func fillingFromEmptyIsIdentity() {
        let caller = AudioMetadata(title: "Anthem", artist: "Someone")

        #expect(caller.filling(from: AudioMetadata()) == caller)
    }

    @Test(
        "Subtitle joins the parts that exist",
        arguments: [
            (AudioMetadata(artist: "Someone", album: "Debut"), "Someone — Debut"),
            (AudioMetadata(artist: "Someone"), "Someone"),
            (AudioMetadata(album: "Debut"), "Debut"),
            (AudioMetadata(title: "Anthem"), nil)
        ] as [(AudioMetadata, String?)]
    )
    func subtitle(_ metadata: AudioMetadata, _ expected: String?) {
        #expect(metadata.subtitle == expected)
    }
}
