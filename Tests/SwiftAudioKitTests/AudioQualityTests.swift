//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Audio quality")
struct AudioQualityTests {
    @Test(
        "Stepping between neighbours stops at the ends",
        arguments: [
            (AudioQuality.low, nil, AudioQuality.medium),
            (AudioQuality.medium, AudioQuality.low, AudioQuality.high),
            (AudioQuality.high, AudioQuality.medium, nil),
        ] as [(AudioQuality, AudioQuality?, AudioQuality?)]
    )
    func stepping(_ quality: AudioQuality, _ lower: AudioQuality?, _ higher: AudioQuality?) {
        #expect(quality.lower == lower)
        #expect(quality.higher == higher)
    }

    @Test("Ordering follows fidelity")
    func ordering() {
        #expect(AudioQuality.low < AudioQuality.medium)
        #expect(AudioQuality.medium < AudioQuality.high)
    }
}
