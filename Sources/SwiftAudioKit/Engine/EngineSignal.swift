//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

enum EngineStatus: Sendable, Hashable {
    case idle
    case loading
    case ready
    case failed(PlaybackFailure)
}

enum EngineTimeControl: Sendable, Hashable {
    case paused
    case waiting(reason: WaitingReason?)
    case playing

    enum WaitingReason: Sendable, Hashable {
        case evaluatingBufferingRate
        case minimizingStalls
        case noItemToPlay
    }

    /// Apple asks callers not to show a waiting indicator while the buffering rate is still
    /// being evaluated, and there is nothing to wait for when no item is loaded.
    var showsLoadingIndicator: Bool {
        switch self {
        case .paused, .playing:
            false
        case let .waiting(reason):
            switch reason {
            case .evaluatingBufferingRate, .noItemToPlay:
                false
            case .minimizingStalls, nil:
                true
            }
        }
    }
}

enum EngineSignal: Sendable, Hashable {
    case statusChanged(EngineStatus)
    case timeControlChanged(EngineTimeControl)
    case playheadMoved(Duration)
    case durationResolved(Duration)
    case bufferChanged(loaded: ClosedRange<Duration>?, seekable: ClosedRange<Duration>?)
    case reachedEnd
    case metadataReceived([MetadataEntry])
    case failed(PlaybackFailure)
    case errorLogged(PlaybackFailure)
}
