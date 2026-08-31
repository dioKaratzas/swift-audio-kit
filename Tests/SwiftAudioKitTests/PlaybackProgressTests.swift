//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Playback progress")
struct PlaybackProgressTests {
    @Test
    func `A known duration yields a fraction and a remainder`() {
        let progress = PlaybackProgress(elapsed: .seconds(30), duration: .seconds(120))

        #expect(progress.fraction == 0.25)
        #expect(progress.remaining == .seconds(90))
        #expect(!progress.isLive)
    }

    @Test
    func `An unknown duration reads as live`() {
        let progress = PlaybackProgress(elapsed: .seconds(30))

        #expect(progress.fraction == nil)
        #expect(progress.remaining == nil)
        #expect(progress.isLive)
    }

    @Test
    func `A zero duration yields no fraction`() {
        #expect(PlaybackProgress(elapsed: .zero, duration: .zero).fraction == nil)
    }

    @Test
    func `The fraction stays within its bounds when the playhead overshoots`() {
        let progress = PlaybackProgress(elapsed: .seconds(130), duration: .seconds(120))

        #expect(progress.fraction == 1)
        #expect(progress.remaining == .zero)
    }

    @Test
    func `Buffered ahead measures from the playhead`() {
        let progress = PlaybackProgress(elapsed: .seconds(30), buffered: .seconds(0) ... .seconds(45))

        #expect(progress.bufferedAhead == .seconds(15))
    }

    @Test
    func `Buffered ahead never goes negative`() {
        let progress = PlaybackProgress(elapsed: .seconds(60), buffered: .seconds(0) ... .seconds(45))

        #expect(progress.bufferedAhead == .zero)
    }

    @Test
    func `Seeking is clamped inside the seekable range`() {
        let progress = PlaybackProgress(elapsed: .zero, seekable: .seconds(10) ... .seconds(100))

        #expect(progress.clampingToSeekableRange(.seconds(50)) == .seconds(50))
        #expect(progress.clampingToSeekableRange(.seconds(0)) == .seconds(11))
        #expect(progress.clampingToSeekableRange(.seconds(500)) == .seconds(99))
    }

    @Test
    func `Seeking without a seekable range only refuses negative times`() {
        let progress = PlaybackProgress(elapsed: .zero)

        #expect(progress.clampingToSeekableRange(.seconds(-5)) == .zero)
        #expect(progress.clampingToSeekableRange(.seconds(50)) == .seconds(50))
    }
}
