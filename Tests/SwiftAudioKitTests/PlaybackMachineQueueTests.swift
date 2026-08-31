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
    static let third = AudioItem(url: URL(string: "https://example.com/3.mp3")!)
    static let online = NetworkStatus(reachability: .available, interface: .wifi)
}

private extension PlaybackMachine {
    static func playing(_ items: [AudioItem] = [Tracks.first, Tracks.second]) -> PlaybackMachine {
        var machine = PlaybackMachine()
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

@Suite("Playback machine queue editing")
struct PlaybackMachineQueueTests {
    @Test("Inserting next puts a track straight after the one playing")
    func insertNext() {
        var machine = PlaybackMachine.playing()

        machine.send(.insertNext(Tracks.third))

        #expect(machine.queue.upNext.first == Tracks.third)
    }

    @Test("Removing a queued track leaves playback alone")
    func removeQueued() {
        var machine = PlaybackMachine.playing()

        machine.send(.remove(Tracks.second.id))

        #expect(machine.state.item == Tracks.first)
        #expect(machine.queue.upNext.isEmpty)
    }

    @Test("Removing the playing track moves to what replaced it")
    func removePlaying() {
        var machine = PlaybackMachine.playing()

        machine.send(.remove(Tracks.first.id))

        #expect(machine.state.item == Tracks.second)
    }

    @Test("Removing the only track stops the player")
    func removeLast() {
        var machine = PlaybackMachine.playing([Tracks.first])

        machine.send(.remove(Tracks.first.id))

        #expect(machine.state == .idle)
    }

    @Test("Clearing the queue stops and empties")
    func clearing() {
        var machine = PlaybackMachine.playing()

        machine.send(.removeAll)

        #expect(machine.state == .idle)
        #expect(machine.queue.isEmpty)
    }

    @Test("Jumping plays the chosen track")
    func jumping() {
        var machine = PlaybackMachine.playing([Tracks.first, Tracks.second, Tracks.third])

        machine.send(.jump(Tracks.third.id))

        #expect(machine.state.item == Tracks.third)
        #expect(machine.intent == .play)
    }

    @Test("A metered link uses the reduced bitrate ceiling")
    func reducedBitrateOnMeteredLinks() {
        var machine = PlaybackMachine(configuration: AudioPlayerConfiguration(
            buffering: BufferingPolicy(preferredPeakBitRate: 320_000, preferredPeakBitRateOnExpensiveNetworks: 96000)
        ))
        machine.send(.network(NetworkStatus(reachability: .available, interface: .cellular, isExpensive: true)))

        let effects = machine.send(.playItems([Tracks.first], startingAt: 0))
        let request = effects.compactMap { effect -> PlaybackRequest? in
            guard case let .load(request, _) = effect else {
                return nil
            }
            return request
        }.first

        #expect(request?.preferredPeakBitRate == 96000)
    }

    @Test("An unmetered link keeps the full bitrate ceiling")
    func fullBitrateOnUnmeteredLinks() {
        var machine = PlaybackMachine(configuration: AudioPlayerConfiguration(
            buffering: BufferingPolicy(preferredPeakBitRate: 320_000, preferredPeakBitRateOnExpensiveNetworks: 96000)
        ))
        machine.send(.network(Tracks.online))

        let effects = machine.send(.playItems([Tracks.first], startingAt: 0))
        let request = effects.compactMap { effect -> PlaybackRequest? in
            guard case let .load(request, _) = effect else {
                return nil
            }
            return request
        }.first

        #expect(request?.preferredPeakBitRate == 320_000)
    }

    @Test("A logged stream error is reported rather than dropped")
    func recoverableErrors() {
        var machine = PlaybackMachine.playing()
        let failure = PlaybackFailure(domain: "CoreMediaErrorDomain", code: -12660, message: "Segment 404")

        let effects = machine.send(.engine(.errorLogged(failure)))

        #expect(effects.contains(.emit(.recoverableErrorLogged(failure))))
        #expect(machine.state.isPlaying)
    }
}
