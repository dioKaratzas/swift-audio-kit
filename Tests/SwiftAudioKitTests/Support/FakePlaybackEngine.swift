//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

@testable import SwiftAudioKit

@MainActor
final class FakePlaybackEngine: PlaybackEngine {
    let signals: AsyncStream<EngineSignal>

    private let continuation: AsyncStream<EngineSignal>.Continuation

    private(set) var loaded = [PlaybackRequest]()
    private(set) var seeks = [Duration]()
    private(set) var unloadCount = 0
    private(set) var playCount = 0
    private(set) var pauseCount = 0

    var seekResult = true
    var progress = PlaybackProgress.zero
    var timeControl = EngineTimeControl.paused
    var volume: Float = 1
    var defaultRate: Float = 1

    init() {
        (signals, continuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    func load(_ request: PlaybackRequest) async {
        loaded.append(request)
    }

    func unload() {
        unloadCount += 1
    }

    func play() {
        playCount += 1
    }

    func pause() {
        pauseCount += 1
    }

    func seek(to time: Duration, tolerance: SeekTolerance) async -> Bool {
        seeks.append(time)
        return seekResult
    }

    /// Pushes a signal as the real engine would, so tests drive the player through its own seam.
    func emit(_ signal: EngineSignal) {
        continuation.yield(signal)
    }
}
