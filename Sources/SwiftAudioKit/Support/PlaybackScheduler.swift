//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// One requirement, so tests can drive retry and deadline timing without waiting on a clock.
protocol PlaybackScheduler: Sendable {
    func sleep(for duration: Duration) async throws
}

struct SystemScheduler: PlaybackScheduler {
    func sleep(for duration: Duration) async throws {
        try await ContinuousClock().sleep(for: duration)
    }
}
