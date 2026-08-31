//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// Everything that stops playback for good, as opposed to the stalls the player rides out.
///
/// A value of this type means the player has given up. Transient trouble is reported through
/// ``AudioPlayer/state`` instead and never reaches here. Errors arrive carried by
/// ``PlaybackState/failed(item:error:)``, emitted as ``AudioPlayerEvent/failed(_:)``, and
/// thrown by ``AudioPlayer/prepareForPlayback()``.
public enum AudioPlayerError: Error, Sendable, Hashable {
    /// The retry budget for an item ran out.
    ///
    /// Raised after ``RetryPolicy/maximumAttempts`` loads have failed for the same track. The
    /// count resets on every track change, so this is always about one item. The associated
    /// value is how many attempts were spent.
    case retryLimitReached(attempts: Int)

    /// The engine could not play the item.
    ///
    /// The associated ``PlaybackFailure`` carries what AVFoundation reported — its domain,
    /// code and localised message — flattened into a `Sendable` value.
    case playbackFailed(PlaybackFailure)

    /// No usable network path came back before the deadline expired.
    ///
    /// The player waits in ``PlaybackState/waitingForConnection(_:)`` for
    /// ``AudioPlayerConfiguration/maximumConnectionLossTime`` before raising this. Local
    /// items never wait and so never produce it. The associated value is the deadline that
    /// expired.
    case connectionLost(after: Duration)

    /// A named item cannot be played and was given up on.
    ///
    /// The associated value is the ``AudioItem/id`` of the track that was abandoned.
    case itemUnavailable(AudioItem.ID)

    /// Playback was asked for but the queue holds nothing that can be played.
    ///
    /// Raised when the queue is empty, and when every track in it is listed in
    /// ``AudioPlayer/skippedItems``.
    case noPlayableItems

    /// The audio session refused to configure or activate.
    ///
    /// Usually another app holds a session that will not yield, such as an in-progress call.
    /// This is the only case ``AudioPlayer/prepareForPlayback()`` can throw.
    case audioSessionFailed(PlaybackFailure)

    /// Whether playing again is worth trying.
    ///
    /// This describes the error, not the player's intent: the player has already stopped in
    /// every case. `true` for ``playbackFailed(_:)``, ``connectionLost(after:)`` and
    /// ``audioSessionFailed(_:)``, which can succeed on a later attempt; `false` for
    /// ``retryLimitReached(attempts:)``, ``itemUnavailable(_:)`` and ``noPlayableItems``,
    /// where trying the same thing again would fail the same way.
    public var isRetryable: Bool {
        switch self {
        case .playbackFailed, .connectionLost, .audioSessionFailed:
            true
        case .retryLimitReached, .itemUnavailable, .noPlayableItems:
            false
        }
    }

    /// The underlying system error, where one crossed out of AVFoundation to cause this.
    ///
    /// Set for ``playbackFailed(_:)`` and ``audioSessionFailed(_:)``, and `nil` for the cases
    /// the player raises itself. Use it to match a specific domain and code.
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
    /// A description of the failure written for a listener rather than a developer.
    ///
    /// Never names a domain or a code, so it is safe to put straight into an alert. Read
    /// ``failure`` when you need the machine-readable detail instead.
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
