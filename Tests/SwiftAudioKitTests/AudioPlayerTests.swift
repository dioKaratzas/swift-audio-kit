//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

private enum Tracks {
    static let first = AudioItem(url: URL(string: "https://example.com/1.mp3")!)
    static let second = AudioItem(url: URL(string: "https://example.com/2.mp3")!)
    static let online = NetworkStatus(reachability: .available, interface: .wifi)
}

@MainActor
private struct Harness {
    let player: AudioPlayer
    let engine: FakePlaybackEngine
    let scheduler: TestScheduler

    init(configuration: AudioPlayerConfiguration = .default) {
        engine = FakePlaybackEngine()
        scheduler = TestScheduler()
        player = AudioPlayer(configuration: configuration, engine: engine, scheduler: scheduler)
    }

    /// Lets the engine-signal loop and any spawned load tasks run to quiescence.
    func settle() async {
        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    func startPlaying(_ items: [AudioItem] = [Tracks.first, Tracks.second]) async {
        player.play(items)
        await settle()
        engine.emit(.statusChanged(.ready))
        await settle()
    }
}

@Suite("Audio player")
@MainActor
struct AudioPlayerTests {
    @Test("Playing a queue loads the first track")
    func playing() async {
        let harness = Harness()

        harness.player.play([Tracks.first, Tracks.second])
        await harness.settle()

        #expect(harness.player.state == .loading(Tracks.first))
        #expect(harness.engine.loaded.count == 1)
    }

    @Test("Engine readiness moves the player to playing")
    func readiness() async {
        let harness = Harness()
        await harness.startPlaying()

        #expect(harness.player.state == .playing(Tracks.first))
        #expect(harness.engine.playCount == 1)
    }

    @Test("Observable state follows the engine")
    func observableState() async {
        let harness = Harness()
        await harness.startPlaying()

        harness.engine.emit(.durationResolved(.seconds(120)))
        harness.engine.emit(.playheadMoved(.seconds(30)))
        await harness.settle()

        #expect(harness.player.progress.fraction == 0.25)
        #expect(harness.player.currentItem == Tracks.first)
    }

    @Test("Up next reflects what remains")
    func upNext() async {
        let harness = Harness()
        await harness.startPlaying()

        #expect(harness.player.upNext == [Tracks.second])
        #expect(harness.player.hasNext)
        #expect(!harness.player.hasPrevious)
    }

    @Test("Events reach every subscriber")
    func multicastEvents() async {
        let harness = Harness()
        var firstStream = harness.player.events.makeAsyncIterator()
        var secondStream = harness.player.events.makeAsyncIterator()

        harness.player.play([Tracks.first])
        await harness.settle()

        #expect(await firstStream.next() != nil)
        #expect(await secondStream.next() != nil)
    }

    @Test("Volume and rate reach the engine")
    func settingsForwarded() {
        let harness = Harness()

        harness.player.volume = 0.5
        harness.player.rate = 1.5

        #expect(harness.engine.volume == 0.5)
        #expect(harness.engine.defaultRate == 1.5)
    }

    @Test("Seeking clamps to the seekable range")
    func seekClamping() async {
        let harness = Harness()
        await harness.startPlaying()
        harness.engine.emit(.bufferChanged(loaded: nil, seekable: .seconds(10) ... .seconds(100)))
        await harness.settle()

        await harness.player.seek(to: .seconds(500))

        #expect(harness.engine.seeks.last == .seconds(99))
    }

    @Test("Retry fires only once the timeout elapses")
    func retryTiming() async {
        let harness = Harness(configuration: AudioPlayerConfiguration(
            retry: RetryPolicy(maximumAttempts: 3, timeout: .seconds(10))
        ))
        await harness.startPlaying([Tracks.first])
        harness.engine.emit(.failed(PlaybackFailure(domain: "Test", code: 1, message: "Boom")))
        await harness.settle()

        let loadsBefore = harness.engine.loaded.count
        await harness.scheduler.advance(by: .seconds(9))
        await harness.settle()
        #expect(harness.engine.loaded.count == loadsBefore)

        await harness.scheduler.advance(by: .seconds(1))
        await harness.settle()
        #expect(harness.engine.loaded.count == loadsBefore + 1)
    }

    @Test("Stopping unloads the engine")
    func stopping() async {
        let harness = Harness()
        await harness.startPlaying()

        harness.player.stop()
        await harness.settle()

        #expect(harness.player.state == .idle)
        #expect(harness.engine.unloadCount >= 1)
    }

    @Test("Finishing the last track empties the player")
    func queueExhaustion() async {
        let harness = Harness()
        var events = harness.player.events.makeAsyncIterator()
        await harness.startPlaying([Tracks.first])

        harness.engine.emit(.reachedEnd)
        await harness.settle()

        #expect(harness.player.state == .idle)
        #expect(harness.player.currentItem == nil)

        var sawExhausted = false
        while let event = await events.next() {
            if case .queueExhausted = event {
                sawExhausted = true
                break
            }
        }
        #expect(sawExhausted)
    }

    @Test("Skipped tracks are stepped over")
    func skipping() async {
        let harness = Harness()
        harness.player.skippedItems = [Tracks.second.id]
        await harness.startPlaying()

        harness.engine.emit(.reachedEnd)
        await harness.settle()

        #expect(harness.player.state == .idle)
    }
}

@Suite("Audio player restored surface")
@MainActor
struct AudioPlayerRestoredSurfaceTests {
    @Test("The queue position follows the playing track")
    func currentIndex() async {
        let harness = Harness()
        #expect(harness.player.currentIndex == nil)

        await harness.startPlaying()
        #expect(harness.player.currentIndex == 0)

        harness.player.next()
        await harness.settle()
        #expect(harness.player.currentIndex == 1)
    }

    @Test("Seeking to the live edge lands inside the seekable range")
    func seekToLiveEdge() async {
        let harness = Harness()
        await harness.startPlaying()
        harness.engine.emit(.bufferChanged(loaded: nil, seekable: .seconds(10) ... .seconds(100)))
        await harness.settle()

        await harness.player.seekToLiveEdge()

        #expect(harness.engine.seeks.last == .seconds(99))
    }

    @Test("Seeking to the start lands at the earliest kept point")
    func seekToStart() async {
        let harness = Harness()
        await harness.startPlaying()
        harness.engine.emit(.bufferChanged(loaded: nil, seekable: .seconds(10) ... .seconds(100)))
        await harness.settle()

        await harness.player.seekToStart()

        #expect(harness.engine.seeks.last == .seconds(11))
    }

    @Test("A live stream with no seekable range cannot reach the edge")
    func liveEdgeWithoutRange() async {
        let harness = Harness()
        await harness.startPlaying()

        #expect(await !harness.player.seekToLiveEdge())
    }
}
