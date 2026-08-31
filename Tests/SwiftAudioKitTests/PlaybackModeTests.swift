//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Playback mode")
struct PlaybackModeTests {
    @Test
    func `Cycling the repeat mode returns to where it started`() {
        var mode = RepeatMode.off

        for _ in RepeatMode.allCases {
            mode = mode.next
        }

        #expect(mode == .off)
    }

    @Test
    func `Cycling visits every mode`() {
        var visited = Set<RepeatMode>()
        var mode = RepeatMode.off

        for _ in RepeatMode.allCases {
            visited.insert(mode)
            mode = mode.next
        }

        #expect(visited == Set(RepeatMode.allCases))
    }

    @Test
    func `Repeat and shuffle are independent`() {
        let mode = PlaybackMode(repeatMode: .all, isShuffled: true)

        #expect(mode.repeatMode == .all)
        #expect(mode.isShuffled)
        #expect(PlaybackMode.normal == PlaybackMode(repeatMode: .off, isShuffled: false))
        #expect(PlaybackMode.repeatOne.repeatMode == .one)
        #expect(!PlaybackMode.repeatAll.isShuffled)
    }
}
