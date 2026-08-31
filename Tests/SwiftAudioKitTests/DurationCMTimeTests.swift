//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import CoreMedia
@testable import SwiftAudioKit

@Suite("Duration and CMTime")
struct DurationCMTimeTests {
    @Test(
        "Durations survive the round trip",
        arguments: [
            Duration.zero,
            .seconds(1),
            .seconds(3661),
            .milliseconds(1500),
            .microseconds(1)
        ]
    )
    func roundTrip(_ duration: Duration) {
        #expect(CMTime(duration: duration).duration == duration)
    }

    @Test("Indefinite and invalid times have no duration")
    func unusableTimes() {
        #expect(CMTime.indefinite.duration == nil)
        #expect(CMTime.invalid.duration == nil)
    }

    @Test("A time range converts to a closed range")
    func timeRange() {
        let range = CMTimeRange(start: CMTime(duration: .seconds(5)), duration: CMTime(duration: .seconds(10)))

        #expect(range.durationRange == .seconds(5) ... .seconds(15))
    }

    @Test("A range built on an indefinite bound is discarded")
    func indefiniteRange() {
        #expect(CMTimeRange(start: .zero, duration: .indefinite).durationRange == nil)
    }
}
