//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

@testable import SwiftAudioKit

/// Parks every sleep until a test advances the clock, so retry and deadline timing is exact.
actor TestScheduler: PlaybackScheduler {
    private struct Sleeper {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var now = Duration.zero
    private var sleepers = [Sleeper]()

    nonisolated func sleep(for duration: Duration) async throws {
        try await park(for: duration)
    }

    func advance(by duration: Duration) async {
        now += duration

        let due = sleepers.filter { $0.deadline <= now }
        sleepers.removeAll { $0.deadline <= now }

        for sleeper in due.sorted(by: { $0.deadline < $1.deadline }) {
            sleeper.continuation.resume()
        }
        await Task.yield()
    }

    var pendingSleepCount: Int {
        sleepers.count
    }

    private func park(for duration: Duration) async throws {
        let deadline = now + duration
        try await withCheckedThrowingContinuation { continuation in
            sleepers.append(Sleeper(deadline: deadline, continuation: continuation))
        }
    }
}
