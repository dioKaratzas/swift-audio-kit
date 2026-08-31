//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Playback mode")
struct PlaybackModeTests {
    @Test("Cycling returns to where it started", arguments: RepeatMode.allCases)
    func cyclingIsClosed(_ start: RepeatMode) {
        var mode = start

        for _ in RepeatMode.allCases {
            mode = mode.next
        }

        #expect(mode == start)
    }

    @Test("Cycling visits every mode")
    func cyclingIsExhaustive() {
        var visited = Set<RepeatMode>()
        var mode = RepeatMode.off

        for _ in RepeatMode.allCases {
            visited.insert(mode)
            mode = mode.next
        }

        #expect(visited == Set(RepeatMode.allCases))
    }
}
