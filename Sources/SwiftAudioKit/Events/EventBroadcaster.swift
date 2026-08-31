//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// Hands every caller its own stream, because one shared continuation would starve
/// the second consumer.
@MainActor
final class EventBroadcaster {
    private var continuations = [UUID: AsyncStream<AudioPlayerEvent>.Continuation]()

    func makeStream() -> AsyncStream<AudioPlayerEvent> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AudioPlayerEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(64)
        )

        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    func emit(_ event: AudioPlayerEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    func finish() {
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }
}
