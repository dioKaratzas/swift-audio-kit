//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

private enum Tracks {
    static let remote = AudioItem(url: URL(string: "https://example.com/1.mp3")!)
    static let second = AudioItem(url: URL(string: "https://example.com/2.mp3")!)
    static let local = AudioItem(url: URL(fileURLWithPath: "/tmp/local.mp3"))

    static let online = NetworkStatus(reachability: .available, interface: .wifi)
    static let offline = NetworkStatus.unavailable

    static let lowURL = URL(string: "https://example.com/low.mp3")!
    static let highURL = URL(string: "https://example.com/high.mp3")!
    static let multiQuality = AudioSources([.low: lowURL, .high: highURL])!
}

private extension PlaybackMachine {
    /// Drives the machine to the point where a track is actually playing.
    static func playing(
        _ items: [AudioItem] = [Tracks.remote, Tracks.second],
        configuration: AudioPlayerConfiguration = .default
    ) -> PlaybackMachine {
        var machine = PlaybackMachine(configuration: configuration)
        _ = machine.handle(.network(Tracks.online))
        _ = machine.handle(.playItems(items, startingAt: 0))
        _ = machine.handle(.engine(.statusChanged(.ready)))
        return machine
    }

    @discardableResult
    mutating func send(_ signal: Signal) -> [Effect] {
        handle(signal)
    }
}

private extension [Effect] {
    var events: [AudioPlayerEvent] {
        compactMap { effect in
            guard case let .emit(event) = effect else {
                return nil
            }
            return event
        }
    }

    func loads() -> [PlaybackRequest] {
        compactMap { effect in
            guard case let .load(request, _) = effect else {
                return nil
            }
            return request
        }
    }
}

@Suite("Playback machine")
struct PlaybackMachineTests {
    // MARK: Starting playback

    @Test("Playing a queue loads the first track and takes the session")
    func startsPlayback() {
        var machine = PlaybackMachine()
        machine.send(.network(Tracks.online))

        let effects = machine.send(.playItems([Tracks.remote, Tracks.second], startingAt: 0))

        #expect(machine.state == .loading(Tracks.remote))
        #expect(effects.contains(.activateSession))
        #expect(effects.contains(.beginBackgroundActivity))
        #expect(effects.loads().first?.url == Tracks.remote.sources.highest.url)
    }

    @Test("Readiness starts playback when the listener asked for it")
    func readyStartsPlaying() {
        var machine = PlaybackMachine()
        machine.send(.network(Tracks.online))
        machine.send(.playItems([Tracks.remote], startingAt: 0))

        let effects = machine.send(.engine(.statusChanged(.ready)))

        #expect(machine.state == .playing(Tracks.remote))
        #expect(effects.contains(.play))
        #expect(effects.contains(.endBackgroundActivity))
    }

    @Test("An empty queue fails rather than pretending to play")
    func emptyQueueFails() {
        var machine = PlaybackMachine()

        let effects = machine.send(.playItems([], startingAt: 0))

        #expect(machine.state.error == .noPlayableItems)
        #expect(effects.events.contains(.failed(.noPlayableItems)))
    }

    // MARK: Intent

    @Test("Pausing records the listener's intent, so readiness does not start playback")
    func pauseSurvivesReload() {
        var machine = PlaybackMachine.playing()
        machine.send(.pause)

        machine.send(.engine(.statusChanged(.ready)))

        #expect(machine.state.isPaused)
        #expect(machine.intent == .pause)
    }

    @Test("Stopping releases the session and clears the track")
    func stopping() {
        var machine = PlaybackMachine.playing()

        let effects = machine.send(.stop)

        #expect(machine.state == .idle)
        #expect(effects.contains(.unload))
        #expect(effects.contains(.deactivateSession))
    }

    // MARK: Queue traversal

    @Test("Finishing a track reports it and moves on")
    func finishingAdvances() {
        var machine = PlaybackMachine.playing()

        let effects = machine.send(.engine(.reachedEnd))

        #expect(effects.events.contains(.itemFinished(Tracks.remote)))
        #expect(machine.state.item == Tracks.second)
    }

    @Test("Finishing the last track reports an exhausted queue and stops")
    func exhaustingQueue() {
        var machine = PlaybackMachine.playing([Tracks.remote])

        let effects = machine.send(.engine(.reachedEnd))

        #expect(effects.events.contains(.queueExhausted))
        #expect(machine.state == .idle)
    }

    @Test("Going back before the first track seeks to the start instead")
    func previousAtStart() {
        var machine = PlaybackMachine.playing()

        let effects = machine.send(.previous)

        #expect(effects.contains { effect in
            if case .seek(.zero, _) = effect {
                true
            } else {
                false
            }
        })
    }

    // MARK: Failure and retry

    @Test("A failure schedules a retry rather than surfacing immediately")
    func failureRetries() {
        var machine = PlaybackMachine.playing()

        let effects = machine.send(.engine(.failed(PlaybackFailure(domain: "Test", code: 1, message: "Boom"))))

        #expect(machine.state.isBuffering)
        #expect(effects.contains { effect in
            if case .scheduleRetry = effect {
                true
            } else {
                false
            }
        })
    }

    @Test("A retry reloads the track and restores the playhead")
    func retryRestoresPosition() {
        var machine = PlaybackMachine.playing()
        machine.send(.engine(.playheadMoved(.seconds(30))))
        machine.send(.engine(.failed(PlaybackFailure(domain: "Test", code: 1, message: "Boom"))))

        let effects = machine.send(.retryDue(generation: machine.generation))

        #expect(effects.loads().count == 1)
        #expect(effects.contains { effect in
            if case .seek(.seconds(30), _) = effect {
                true
            } else {
                false
            }
        })
    }

    @Test("A retry for a track already skipped past is ignored")
    func staleRetryIgnored() {
        var machine = PlaybackMachine.playing()
        let stale = machine.generation
        machine.send(.engine(.failed(PlaybackFailure(domain: "Test", code: 1, message: "Boom"))))
        machine.send(.next)

        let effects = machine.send(.retryDue(generation: stale))

        #expect(effects.loads().isEmpty)
    }

    @Test("Exhausting the retries fails with the attempt count")
    func retryLimit() {
        var machine = PlaybackMachine.playing(configuration: AudioPlayerConfiguration(
            retry: RetryPolicy(maximumAttempts: 2, timeout: .seconds(1))
        ))
        let failure = PlaybackFailure(domain: "Test", code: 1, message: "Boom")

        machine.send(.engine(.failed(failure)))
        machine.send(.engine(.failed(failure)))
        let effects = machine.send(.engine(.failed(failure)))

        #expect(machine.state.error == .retryLimitReached(attempts: 2))
        #expect(effects.contains(.unload))
    }

    // MARK: Connection

    @Test("Losing the connection parks playback and starts the deadline")
    func connectionLost() {
        var machine = PlaybackMachine.playing()

        let effects = machine.send(.network(Tracks.offline))

        #expect(machine.state == .waitingForConnection(Tracks.remote))
        #expect(effects.contains(.pause))
        #expect(effects.contains { effect in
            if case .startConnectionLossTimer = effect {
                true
            } else {
                false
            }
        })
    }

    @Test("Regaining the connection reloads the track")
    func connectionRestored() {
        var machine = PlaybackMachine.playing()
        machine.send(.network(Tracks.offline))

        let effects = machine.send(.network(Tracks.online))

        #expect(effects.contains(.cancelConnectionLossTimer))
        #expect(effects.loads().count == 1)
    }

    @Test("A local track plays with no connection at all")
    func localTrackIgnoresNetwork() {
        var machine = PlaybackMachine()
        machine.send(.network(Tracks.offline))

        machine.send(.playItems([Tracks.local], startingAt: 0))

        #expect(machine.state == .loading(Tracks.local))
    }

    @Test("Passing the deadline while offline fails")
    func connectionDeadline() {
        var machine = PlaybackMachine.playing()
        machine.send(.network(Tracks.offline))

        machine.send(.connectionLossDeadlineReached(generation: machine.generation))

        #expect(machine.state.error == .connectionLost(after: .seconds(60)))
    }

    // MARK: Interruption

    @Test("An interruption pauses, and its end resumes when the listener wanted to play")
    func interruptionResumes() {
        var machine = PlaybackMachine.playing()

        machine.send(.interrupted(.interruption))
        #expect(machine.state.pauseReason == .interruption)

        let effects = machine.send(.interruptionEnded(shouldResume: true))
        #expect(effects.contains(.play))
    }

    @Test("An interruption does not resume when the configuration forbids it")
    func interruptionDoesNotResume() {
        var machine = PlaybackMachine.playing(configuration: AudioPlayerConfiguration(
            resumesAfterInterruption: false
        ))
        machine.send(.interrupted(.interruption))

        let effects = machine.send(.interruptionEnded(shouldResume: true))

        #expect(!effects.contains(.play))
        #expect(machine.state.isPaused)
    }

    @Test("A pause the listener asked for is not undone by an interruption ending")
    func manualPauseIsNotResumed() {
        var machine = PlaybackMachine.playing()
        machine.send(.pause)

        let effects = machine.send(.interruptionEnded(shouldResume: true))

        #expect(!effects.contains(.play))
    }

    // MARK: Quality

    @Test("Changing quality reloads at the new URL and keeps the playhead")
    func qualityChangeReloads() {
        let item = AudioItem(sources: Tracks.multiQuality)
        var machine = PlaybackMachine.playing([item])
        machine.send(.engine(.playheadMoved(.seconds(12))))

        let effects = machine.send(.setQuality(.low))

        #expect(machine.quality == .low)
        #expect(effects.loads().first?.url.lastPathComponent == "low.mp3")
        #expect(effects.contains { effect in
            if case .seek(.seconds(12), _) = effect {
                true
            } else {
                false
            }
        })
    }

    @Test("Repeated stalls step the quality down once the threshold is met")
    func stallsDowngradeQuality() {
        var machine = PlaybackMachine.playing(
            [AudioItem(sources: Tracks.multiQuality)],
            configuration: AudioPlayerConfiguration(quality: .automatic(downgradeAfterInterruptions: 2))
        )

        machine.send(.engine(.timeControlChanged(.waiting(reason: .minimizingStalls))))
        #expect(machine.quality == .high)

        machine.send(.engine(.timeControlChanged(.playing)))
        let effects = machine.send(.engine(.timeControlChanged(.waiting(reason: .minimizingStalls))))

        #expect(machine.quality == .medium)
        #expect(effects.loads().first?.url.lastPathComponent == "low.mp3")
    }

    @Test("A fixed quality policy never steps down")
    func fixedQualityHolds() {
        var machine = PlaybackMachine.playing(configuration: AudioPlayerConfiguration(quality: .fixed))

        for _ in 0 ..< 10 {
            machine.send(.engine(.timeControlChanged(.waiting(reason: .minimizingStalls))))
            machine.send(.engine(.timeControlChanged(.playing)))
        }

        #expect(machine.quality == .high)
    }

    @Test("Evaluating the buffering rate is not treated as a stall")
    func evaluatingIsNotAStall() {
        var machine = PlaybackMachine.playing(configuration: AudioPlayerConfiguration(
            quality: .automatic(downgradeAfterInterruptions: 1)
        ))

        machine.send(.engine(.timeControlChanged(.waiting(reason: .evaluatingBufferingRate))))

        #expect(machine.quality == .high)
        #expect(machine.state.isPlaying)
    }

    // MARK: Metadata

    @Test("Stream metadata fills the gaps the caller left")
    func metadataFillsGaps() throws {
        let item = try AudioItem(
            url: #require(URL(string: "https://example.com/1.mp3")),
            metadata: AudioMetadata(title: "Caller title")
        )
        var machine = PlaybackMachine.playing([item])

        let effects = machine.send(.engine(.metadataReceived([
            MetadataEntry(commonKey: "title", stringValue: "Stream title"),
            MetadataEntry(commonKey: "artist", stringValue: "Stream artist")
        ])))

        #expect(machine.metadata.title == "Caller title")
        #expect(machine.metadata.artist == "Stream artist")
        #expect(effects.events.contains(.metadataUpdated(machine.metadata, for: item.id)))
    }

    @Test("Unchanged metadata is not re-reported")
    func metadataDoesNotRepeat() {
        var machine = PlaybackMachine.playing([Tracks.remote])
        let entries = [MetadataEntry(commonKey: "title", stringValue: "Anthem")]
        machine.send(.engine(.metadataReceived(entries)))

        let effects = machine.send(.engine(.metadataReceived(entries)))

        #expect(effects.events.isEmpty)
    }

    // MARK: Progress

    @Test("Progress accumulates from the engine")
    func progressTracking() {
        var machine = PlaybackMachine.playing()

        machine.send(.engine(.durationResolved(.seconds(200))))
        machine.send(.engine(.playheadMoved(.seconds(50))))
        machine.send(.engine(.bufferChanged(loaded: .zero ... .seconds(80), seekable: .zero ... .seconds(200))))

        #expect(machine.progress.fraction == 0.25)
        #expect(machine.progress.bufferedAhead == .seconds(30))
    }
}
