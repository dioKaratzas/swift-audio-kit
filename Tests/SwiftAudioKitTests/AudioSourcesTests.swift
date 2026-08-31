//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

private enum Fixtures {
    static let low = URL(string: "https://example.com/low.mp3")!
    static let medium = URL(string: "https://example.com/medium.mp3")!
    static let high = URL(string: "https://example.com/high.mp3")!
    static let file = URL(fileURLWithPath: "/tmp/track.mp3")
}

@Suite("Audio sources")
struct AudioSourcesTests {
    @Test("An empty map has no sources")
    func emptyMapIsRejected() {
        #expect(AudioSources([:]) == nil)
    }

    @Test("A single URL resolves at every requested quality", arguments: AudioQuality.allCases)
    func singleURLResolvesEverywhere(_ requested: AudioQuality) {
        let sources = AudioSources(url: Fixtures.medium, quality: .medium)

        #expect(sources.resolve(preferring: requested).url == Fixtures.medium)
        #expect(sources.resolve(preferring: requested).quality == .medium)
    }

    @Test("An exact match wins", arguments: AudioQuality.allCases)
    func exactMatchWins(_ requested: AudioQuality) throws {
        let sources = try #require(AudioSources([
            .low: Fixtures.low,
            .medium: Fixtures.medium,
            .high: Fixtures.high
        ]))

        #expect(sources.resolve(preferring: requested).quality == requested)
    }

    @Test(
        "A missing quality falls back to the nearest, preferring lower",
        arguments: [
            (Set<AudioQuality>([.low, .high]), AudioQuality.medium, AudioQuality.low),
            (Set([.medium, .high]), .low, .medium),
            (Set([.low, .medium]), .high, .medium),
            (Set([.high]), .low, .high),
            (Set([.low]), .high, .low)
        ] as [(Set<AudioQuality>, AudioQuality, AudioQuality)]
    )
    func fallback(_ available: Set<AudioQuality>, _ requested: AudioQuality, _ expected: AudioQuality) throws {
        let entries = Dictionary(uniqueKeysWithValues: available.map { ($0, Fixtures.high) })
        let sources = try #require(AudioSources(entries))

        #expect(sources.resolve(preferring: requested).quality == expected)
    }

    @Test("Extremes and availability report the underlying map")
    func extremes() throws {
        let sources = try #require(AudioSources([.low: Fixtures.low, .high: Fixtures.high]))

        #expect(sources.highest.url == Fixtures.high)
        #expect(sources.lowest.url == Fixtures.low)
        #expect(sources.availableQualities == [.low, .high])
        #expect(sources[.medium] == nil)
        #expect(sources[.high] == Fixtures.high)
    }

    @Test("Locality requires every source to be local")
    func locality() throws {
        #expect(AudioSources(url: Fixtures.file).isLocal)
        let mixed = try #require(AudioSources([.low: Fixtures.file, .high: Fixtures.high]))

        #expect(!mixed.isLocal)
    }
}
