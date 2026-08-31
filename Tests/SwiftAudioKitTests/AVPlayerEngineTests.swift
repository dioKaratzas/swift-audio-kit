//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
import AVFoundation
@testable import SwiftAudioKit

@Suite("AVPlayer engine", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct AVPlayerEngineTests {
    @Test("Loading a local file reports ready and resolves its duration")
    func loadingLocalFile() async throws {
        let file = try SilentAudio.file(seconds: 2)
        let engine = AVPlayerEngine()
        let collector = SignalCollector(engine)

        await engine.load(PlaybackRequest(url: file.url))
        let signals = await collector.wait { signals in
            signals.contains(.statusChanged(.ready)) && signals.contains { signal in
                if case .durationResolved = signal {
                    true
                } else {
                    false
                }
            }
        }

        #expect(signals.contains(.statusChanged(.ready)), "observed \(signals)")

        let resolved = signals.compactMap { signal -> Duration? in
            guard case let .durationResolved(duration) = signal else {
                return nil
            }
            return duration
        }
        let duration = try #require(resolved.last)

        #expect(duration.totalSeconds == 2.0)
    }

    @Test("Loading a missing file reports a failure")
    func loadingMissingFile() async {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("absent.wav")
        let engine = AVPlayerEngine()
        let collector = SignalCollector(engine)

        await engine.load(PlaybackRequest(url: missing))
        let signals = await collector.wait { signals in
            signals.contains { signal in
                if case .failed = signal {
                    true
                } else {
                    false
                }
            }
        }

        let failed = signals.contains { signal in
            if case .failed = signal {
                true
            } else {
                false
            }
        }
        #expect(failed, "observed \(signals)")
    }

    @Test("Seeking reports whether it landed")
    func seeking() async throws {
        let file = try SilentAudio.file(seconds: 5)
        let engine = AVPlayerEngine()
        let collector = SignalCollector(engine)

        await engine.load(PlaybackRequest(url: file.url))
        _ = await collector.wait { $0.contains(.statusChanged(.ready)) }

        #expect(await engine.seek(to: .seconds(3), tolerance: .exact))
    }

    @Test("Playing advances the playhead")
    func playing() async throws {
        let file = try SilentAudio.file(seconds: 5)
        let engine = AVPlayerEngine()
        engine.playheadInterval = .milliseconds(100)
        let collector = SignalCollector(engine)

        await engine.load(PlaybackRequest(url: file.url))
        engine.play()
        let signals = await collector.wait { signals in
            signals.contains { signal in
                if case let .playheadMoved(time) = signal, time > .zero {
                    true
                } else {
                    false
                }
            }
        }

        let advanced = signals.contains { signal in
            if case let .playheadMoved(time) = signal, time > .zero {
                true
            } else {
                false
            }
        }
        #expect(advanced, "observed \(signals)")
    }
}

/// Drains the engine's signals, returning as soon as the expectation holds so a missing
/// signal fails on a bounded wait rather than hanging.
private actor SignalCollector {
    private var collected = [EngineSignal]()

    @MainActor
    init(_ engine: AVPlayerEngine) {
        let signals = engine.signals
        let collector = self
        Task { await collector.drain(signals) }
    }

    func wait(
        for timeout: Duration = .seconds(10),
        until predicate: @Sendable ([EngineSignal]) -> Bool
    ) async -> [EngineSignal] {
        let deadline = ContinuousClock.now + timeout

        while ContinuousClock.now < deadline {
            if predicate(collected) {
                return collected
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return collected
    }

    private func drain(_ signals: AsyncStream<EngineSignal>) async {
        for await signal in signals {
            collected.append(signal)
        }
    }
}

/// Writes a silent 16-bit mono WAV, so the suite needs no binary fixture.
private struct SilentAudio: ~Copyable {
    let url: URL

    static func file(seconds: Int) throws -> SilentAudio {
        let sampleRate = 8000
        let dataBytes = sampleRate * seconds * 2

        var file = Data()
        file.append(contentsOf: Array("RIFF".utf8))
        file.append(littleEndian: UInt32(36 + dataBytes))
        file.append(contentsOf: Array("WAVEfmt ".utf8))
        file.append(littleEndian: UInt32(16))
        file.append(littleEndian: UInt16(1))
        file.append(littleEndian: UInt16(1))
        file.append(littleEndian: UInt32(sampleRate))
        file.append(littleEndian: UInt32(sampleRate * 2))
        file.append(littleEndian: UInt16(2))
        file.append(littleEndian: UInt16(16))
        file.append(contentsOf: Array("data".utf8))
        file.append(littleEndian: UInt32(dataBytes))
        file.append(Data(count: dataBytes))

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("silence-\(UUID().uuidString).wav")
        try file.write(to: url)
        return SilentAudio(url: url)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

private extension Data {
    mutating func append(littleEndian value: some FixedWidthInteger) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
