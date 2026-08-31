//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Playback progress")
struct PlaybackProgressTests {
    @Test(
        "The fraction is clamped and only exists for a known duration",
        arguments: [
            (Duration.seconds(30), Duration.seconds(120), 0.25),
            (.zero, .seconds(120), 0.0),
            (.seconds(120), .seconds(120), 1.0),
            (.seconds(130), .seconds(120), 1.0)
        ] as [(Duration, Duration, Double)]
    )
    func fraction(_ elapsed: Duration, _ duration: Duration, _ expected: Double) {
        #expect(PlaybackProgress(elapsed: elapsed, duration: duration).fraction == expected)
    }

    @Test("An unknown duration reads as live")
    func liveStream() {
        let progress = PlaybackProgress(elapsed: .seconds(30))

        #expect(progress.fraction == nil)
        #expect(progress.remaining == nil)
        #expect(progress.isLive)
    }

    @Test("A zero duration yields no fraction")
    func zeroDuration() {
        #expect(PlaybackProgress(elapsed: .zero, duration: .zero).fraction == nil)
    }

    @Test(
        "Remaining counts down and never goes negative",
        arguments: [
            (Duration.seconds(30), Duration.seconds(120), Duration.seconds(90)),
            (.seconds(120), .seconds(120), .zero),
            (.seconds(130), .seconds(120), .zero)
        ] as [(Duration, Duration, Duration)]
    )
    func remaining(_ elapsed: Duration, _ duration: Duration, _ expected: Duration) {
        #expect(PlaybackProgress(elapsed: elapsed, duration: duration).remaining == expected)
    }

    @Test(
        "Buffered ahead measures from the playhead and never goes negative",
        arguments: [
            (Duration.zero, Duration.seconds(45)),
            (.seconds(30), .seconds(15)),
            (.seconds(45), .zero),
            (.seconds(60), .zero)
        ] as [(Duration, Duration)]
    )
    func bufferedAhead(_ elapsed: Duration, _ expected: Duration) {
        let progress = PlaybackProgress(elapsed: elapsed, buffered: .zero ... .seconds(45))

        #expect(progress.bufferedAhead == expected)
    }

    @Test(
        "Seeking is clamped inside the seekable range",
        arguments: [
            (Duration.seconds(50), Duration.seconds(50)),
            (.zero, .seconds(11)),
            (.seconds(500), .seconds(99))
        ] as [(Duration, Duration)]
    )
    func clampingWithinRange(_ requested: Duration, _ expected: Duration) {
        let progress = PlaybackProgress(elapsed: .zero, seekable: .seconds(10) ... .seconds(100))

        #expect(progress.clampingToSeekableRange(requested) == expected)
    }

    @Test(
        "Seeking without a seekable range only refuses negative times",
        arguments: [
            (Duration.seconds(-5), Duration.zero),
            (.seconds(50), .seconds(50))
        ] as [(Duration, Duration)]
    )
    func clampingWithoutRange(_ requested: Duration, _ expected: Duration) {
        #expect(PlaybackProgress(elapsed: .zero).clampingToSeekableRange(requested) == expected)
    }
}
