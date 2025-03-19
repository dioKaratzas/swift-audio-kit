//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// The possible errors an `AudioPlayer` can fail with.
///
/// - maximumRetryCountHit: The player hit the maximum retry count.
/// - foundationError: The `AVPlayer` failed to play.
/// - itemNotConsideredPlayable: The current item that should be played is considered unplayable.
/// - noItemsConsideredPlayable: The queue doesn't contain any item that is considered playable.
public enum AudioPlayerError: Error, Equatable {
    case maximumRetryCountHit
    case foundationError(Error)
    case itemNotConsideredPlayable
    case noItemsConsideredPlayable

    public static func == (lhs: AudioPlayerError, rhs: AudioPlayerError) -> Bool {
        switch (lhs, rhs) {
        case (.maximumRetryCountHit, .maximumRetryCountHit),
             (.itemNotConsideredPlayable, .itemNotConsideredPlayable),
             (.noItemsConsideredPlayable, .noItemsConsideredPlayable):
            true
        case let (.foundationError(lhsError), .foundationError(rhsError)):
            (lhsError as NSError).domain == (rhsError as NSError).domain &&
                (lhsError as NSError).code == (rhsError as NSError).code
        default:
            false
        }
    }
}

/// `AudioPlayerState` defines the state an `AudioPlayer` instance can be in.
///
/// - buffering: The player is buffering data before playing them.
/// - playing: The player is playing.
/// - paused: The player is paused.
/// - stopped: The player is stopped.
/// - waitingForConnection: The player is waiting for internet connection.
/// - failed: An error occurred. It contains `AudioPlayerError` if any.
public enum AudioPlayerState: Equatable {
    case buffering
    case playing
    case paused
    case stopped
    case waitingForConnection
    case failed(AudioPlayerError)

    /// A boolean value indicating whether the state is `buffering`.
    public var isBuffering: Bool {
        self == .buffering
    }

    /// A boolean value indicating whether the state is `playing`.
    public var isPlaying: Bool {
        self == .playing
    }

    /// A boolean value indicating whether the state is `paused`.
    public var isPaused: Bool {
        self == .paused
    }

    /// A boolean value indicating whether the state is `stopped`.
    public var isStopped: Bool {
        self == .stopped
    }

    /// A boolean value indicating whether the state is `waitingForConnection`.
    public var isWaitingForConnection: Bool {
        self == .waitingForConnection
    }

    /// A boolean value indicating whether the state is `failed`.
    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    /// The error if the state is `failed`.
    public var error: AudioPlayerError? {
        if case let .failed(error) = self {
            return error
        }
        return nil
    }
}
