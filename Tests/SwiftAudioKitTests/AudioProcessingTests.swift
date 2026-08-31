//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if !os(watchOS)
    import Testing
    import AVFAudio
    import Foundation
    @testable import SwiftAudioKit

    @Suite("Audio processing")
    @MainActor
    struct AudioProcessingTests {
        private func makePlayer(_ engine: FakePlaybackEngine) -> AudioPlayer {
            AudioPlayer(configuration: .default, engine: engine, scheduler: TestScheduler())
        }

        @Test("Units reach the engine as they are assigned")
        func unitsReachTheEngine() {
            let engine = FakePlaybackEngine()
            let player = makePlayer(engine)
            let equalizer = AVAudioUnitEQ(numberOfBands: 1)
            let reverb = AVAudioUnitReverb()

            player.audioProcessing.units = [equalizer, reverb]

            #expect(engine.audioUnits.count == 2)
            #expect(engine.audioUnits.first === equalizer)
            #expect(engine.audioUnits.last === reverb)
        }

        @Test("A unit that changes a block's length never reaches the engine")
        func timeEffectsAreRefused() {
            let engine = FakePlaybackEngine()
            let player = makePlayer(engine)
            let reverb = AVAudioUnitReverb()

            player.audioProcessing.units = [AVAudioUnitTimePitch(), reverb, AVAudioUnitVarispeed()]

            #expect(engine.audioUnits.count == 1)
            #expect(engine.audioUnits.first === reverb)
        }

        @Test("Availability follows what the engine could attach")
        func availabilityFollowsTheEngine() async throws {
            let engine = FakePlaybackEngine()
            let player = makePlayer(engine)
            #expect(!player.audioProcessing.isAvailable)

            engine.supportsAudioProcessing = true
            try player.play(AudioItem(url: #require(URL(string: "https://example.com/anthem.mp3"))))
            await Task.yield()

            #expect(player.audioProcessing.isAvailable)
        }
    }
#endif
