//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Audio quality")
struct AudioQualityTests {
    @Test
    func `Ordering follows fidelity`() {
        #expect(AudioQuality.low < AudioQuality.medium)
        #expect(AudioQuality.medium < AudioQuality.high)
        #expect(AudioQuality.allCases.max() == .high)
    }

    @Test
    func `Stepping stops at the ends`() {
        #expect(AudioQuality.low.lower == nil)
        #expect(AudioQuality.low.higher == .medium)
        #expect(AudioQuality.high.higher == nil)
        #expect(AudioQuality.high.lower == .medium)
    }
}
