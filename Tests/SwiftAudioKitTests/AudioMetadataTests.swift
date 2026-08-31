//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Audio metadata")
struct AudioMetadataTests {
    @Test
    func `Emptiness tracks every field`() {
        #expect(AudioMetadata().isEmpty)
        #expect(!AudioMetadata(title: "Anthem").isEmpty)
        #expect(!AudioMetadata(trackNumber: 3).isEmpty)
    }

    @Test
    func `Filling keeps existing values and adopts missing ones`() {
        let caller = AudioMetadata(title: "Caller title", trackNumber: 1)
        let stream = AudioMetadata(title: "Stream title", artist: "Stream artist", trackCount: 12)

        let merged = caller.filling(from: stream)

        #expect(merged.title == "Caller title")
        #expect(merged.trackNumber == 1)
        #expect(merged.artist == "Stream artist")
        #expect(merged.trackCount == 12)
        #expect(merged.album == nil)
    }

    @Test
    func `Filling from empty metadata changes nothing`() {
        let caller = AudioMetadata(title: "Anthem", artist: "Someone")

        #expect(caller.filling(from: AudioMetadata()) == caller)
    }

    @Test
    func `Subtitle joins the parts that exist`() {
        #expect(AudioMetadata(artist: "Someone", album: "Debut").subtitle == "Someone — Debut")
        #expect(AudioMetadata(artist: "Someone").subtitle == "Someone")
        #expect(AudioMetadata(album: "Debut").subtitle == "Debut")
        #expect(AudioMetadata(title: "Anthem").subtitle == nil)
    }
}
