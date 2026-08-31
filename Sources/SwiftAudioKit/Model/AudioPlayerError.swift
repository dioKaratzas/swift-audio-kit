//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// Everything that stops playback for good, as opposed to the stalls the player rides out.
public enum AudioPlayerError: Error, Sendable, Hashable {
    /// The retry budget ran out, carrying how many attempts were spent.
    case retryLimitReached(attempts: Int)

    /// The engine could not play the item, carrying what AVFoundation said.
    case playbackFailed(PlaybackFailure)

    /// No route came back within the configured deadline, carrying that deadline.
    case connectionLost(after: Duration)

    /// A named item cannot be played and was given up on.
    case itemUnavailable(AudioItem.ID)

    /// Asked to play an empty queue, or one where everything is skipped.
    case noPlayableItems

    /// The audio session refused to configure or activate, usually to another app.
    case audioSessionFailed(PlaybackFailure)

    /// Whether playing again is worth trying, not whether the player still intends to.
    public var isRetryable: Bool {
        switch self {
        case .playbackFailed, .connectionLost, .audioSessionFailed:
            true
        case .retryLimitReached, .itemUnavailable, .noPlayableItems:
            false
        }
    }

    /// The underlying system error, where one crossed out of AVFoundation to cause this.
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
    /// Wording aimed at a listener, so it never names a domain or a code.
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
