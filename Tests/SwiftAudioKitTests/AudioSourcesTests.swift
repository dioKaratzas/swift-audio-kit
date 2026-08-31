//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

@Suite("Audio sources")
struct AudioSourcesTests {
    private let low = URL(string: "https://example.com/low.mp3")!
    private let medium = URL(string: "https://example.com/medium.mp3")!
    private let high = URL(string: "https://example.com/high.mp3")!

    @Test
    func `An empty map has no sources`() {
        #expect(AudioSources([:]) == nil)
    }

    @Test
    func `A single URL resolves at every requested quality`() {
        let sources = AudioSources(url: medium, quality: .medium)

        for quality in AudioQuality.allCases {
            #expect(sources.resolve(preferring: quality).url == medium)
        }
        #expect(sources.highest.quality == .medium)
        #expect(sources.lowest.quality == .medium)
    }

    @Test
    func `An exact match wins`() throws {
        let sources = try #require(AudioSources([.low: low, .medium: medium, .high: high]))

        #expect(sources.resolve(preferring: .low).url == low)
        #expect(sources.resolve(preferring: .medium).url == medium)
        #expect(sources.resolve(preferring: .high).url == high)
    }

    @Test
    func `A missing quality falls back downwards before upwards`() throws {
        let sources = try #require(AudioSources([.low: low, .high: high]))

        #expect(sources.resolve(preferring: .medium).quality == .low)
    }

    @Test
    func `A missing quality falls back upwards when nothing lower exists`() throws {
        let sources = try #require(AudioSources([.medium: medium, .high: high]))

        #expect(sources.resolve(preferring: .low).quality == .medium)
    }

    @Test
    func `Extremes and availability report the underlying map`() throws {
        let sources = try #require(AudioSources([.low: low, .high: high]))

        #expect(sources.highest.url == high)
        #expect(sources.lowest.url == low)
        #expect(sources.availableQualities == [.low, .high])
        #expect(sources[.medium] == nil)
        #expect(sources[.high] == high)
    }

    @Test
    func `Locality requires every source to be local`() throws {
        let file = URL(fileURLWithPath: "/tmp/track.mp3")

        #expect(AudioSources(url: file).isLocal)
        #expect(try !#require(AudioSources([.low: file, .high: high])).isLocal)
    }

    @Test
    func `HLS playlists cannot carry an audio mix`() throws {
        let playlist = try #require(URL(string: "https://example.com/stream.m3u8"))

        #expect(!AudioSources(url: playlist).highest.supportsAudioProcessing)
        #expect(AudioSources(url: high).highest.supportsAudioProcessing)
    }
}
