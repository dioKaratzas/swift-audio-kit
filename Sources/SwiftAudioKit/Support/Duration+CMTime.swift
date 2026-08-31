//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import CoreMedia

extension CMTime {
    init(duration: Duration) {
        let (seconds, attoseconds) = duration.components
        self.init(
            value: seconds * Self.durationTimescale + attoseconds / 1_000_000_000,
            timescale: CMTimeScale(Self.durationTimescale)
        )
    }

    /// `nil` for the indefinite duration a live stream reports, and for invalid times.
    var duration: Duration? {
        guard flags.contains(.valid), !flags.contains(.indefinite) else {
            return nil
        }
        let converted = convertScale(CMTimeScale(Self.durationTimescale), method: .default)
        return .seconds(converted.value) / Int(Self.durationTimescale)
    }

    private static let durationTimescale: Int64 = 1_000_000_000
}

extension CMTimeRange {
    var durationRange: ClosedRange<Duration>? {
        guard let lower = start.duration, let upper = end.duration, lower <= upper else {
            return nil
        }
        return lower ... upper
    }
}
