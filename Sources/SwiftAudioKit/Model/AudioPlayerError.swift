//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

public enum AudioPlayerError: Error, Sendable, Hashable {
    case retryLimitReached(attempts: Int)
    case playbackFailed(PlaybackFailure)
    case connectionLost(after: Duration)
    case itemUnavailable(AudioItem.ID)
    case noPlayableItems
    case audioSessionFailed(PlaybackFailure)

    public var isRetryable: Bool {
        switch self {
        case .playbackFailed, .connectionLost, .audioSessionFailed:
            true
        case .retryLimitReached, .itemUnavailable, .noPlayableItems:
            false
        }
    }

    public var failure: PlaybackFailure? {
        switch self {
        case let .playbackFailed(failure), let .audioSessionFailed(failure):
            failure
        case .retryLimitReached, .connectionLost, .itemUnavailable, .noPlayableItems:
            nil
        }
    }
}

extension AudioPlayerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .retryLimitReached(attempts):
            "Playback failed after \(attempts) attempts."
        case let .playbackFailed(failure):
            failure.message
        case let .connectionLost(after):
            "The connection was lost for more than \(Int(after.totalSeconds)) seconds."
        case .itemUnavailable:
            "The track is unavailable."
        case .noPlayableItems:
            "No track in the queue can be played."
        case let .audioSessionFailed(failure):
            "The audio session could not be configured: \(failure.message)"
        }
    }
}
