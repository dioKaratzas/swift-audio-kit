//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// What the player is doing right now, carrying the track it is doing it to.
///
/// Published on ``AudioPlayer/state``. Every case but ``idle`` carries its ``AudioItem``, so
/// a view can read the track and the phase from one value. The convenience flags —
/// ``isPlaying``, ``isTransient``, ``canPause`` and the rest — cover the questions a UI
/// usually asks.
public enum PlaybackState: Sendable, Hashable {
    /// Nothing is loaded and the audio session has been handed back.
    ///
    /// Where the player starts, and where ``AudioPlayer/stop()``, ``AudioPlayer/removeAll()``
    /// and a queue running out all leave it. Distinct from ``paused(_:reason:)``, which keeps
    /// the item and the session.
    case idle

    /// An item has been handed to the engine, which has not reported it ready yet.
    ///
    /// The first phase of every track.
    case loading(AudioItem)

    /// Playback has stalled for data, or is being retried after a failure.
    ///
    /// Repeated visits are what
    /// ``QualityPolicy/automatic(interval:downgradeAfterInterruptions:)`` counts before
    /// stepping the quality down.
    case buffering(AudioItem)

    /// Sound is coming out.
    case playing(AudioItem)

    /// Stopped where it stands, with the reason it stopped.
    ///
    /// The item stays loaded and the audio session stays active, so resuming is immediate.
    /// The associated ``PauseReason`` decides whether the player may resume on its own.
    case paused(AudioItem, reason: PauseReason)

    /// Holding a remote item until a usable network path appears.
    ///
    /// Entered when ``NetworkStatus/isUsable`` goes false with a remote track loaded, and left
    /// either when a path returns or when
    /// ``AudioPlayerConfiguration/maximumConnectionLossTime`` expires and the player fails
    /// with ``AudioPlayerError/connectionLost(after:)``.
    ///
    /// - Note: Local items never enter this state, because they need no route.
    case waitingForConnection(AudioItem)

    /// The player has given up on the item.
    ///
    /// The item is `nil` when the failure came before a track was chosen — an empty queue, or
    /// an audio session that would not activate. Calling ``AudioPlayer/play()`` from here
    /// reloads the item from scratch rather than resuming.
    case failed(item: AudioItem?, error: AudioPlayerError)

    /// The track this state concerns.
    ///
    /// `nil` only while ``idle``, and while ``failed(item:error:)`` carrying no item. The same
    /// value as ``AudioPlayer/currentItem``, which keeps the metadata you supplied rather than
    /// the merged metadata on ``AudioPlayer/metadata``.
    public var item: AudioItem? {
        switch self {
        case .idle:
            nil
        case let .loading(item), let .buffering(item), let .playing(item),
             let .paused(item, _), let .waitingForConnection(item):
            item
        case let .failed(item, _):
            item
        }
    }

    /// The error that stopped playback, or `nil` when nothing has.
    ///
    /// Set only while ``failed(item:error:)``.
    public var error: AudioPlayerError? {
        guard case let .failed(_, error) = self else {
            return nil
        }
        return error
    }

    /// Why playback stopped, or `nil` when it has not.
    ///
    /// Set only while ``paused(_:reason:)``. Check ``PauseReason/isAutomatic`` to tell a pause
    /// the listener asked for from one the system imposed.
    public var pauseReason: PauseReason? {
        guard case let .paused(_, reason) = self else {
            return nil
        }
        return reason
    }

    /// Whether nothing is loaded.
    ///
    /// The audio session is not held in this state.
    public var isIdle: Bool {
        self == .idle
    }

    /// Whether the engine is still accepting an item it has been handed.
    public var isLoading: Bool {
        if case .loading = self {
            true
        } else {
            false
        }
    }

    /// Whether playback has stalled for data or is waiting out a retry.
    public var isBuffering: Bool {
        if case .buffering = self {
            true
        } else {
            false
        }
    }

    /// Whether sound is actually coming out.
    ///
    /// - Important: Narrower than "the listener asked to play". A track that has stalled is
    ///   ``buffering(_:)`` and reads as `false` here even though playback will resume on its
    ///   own. To drive a play/pause button, prefer ``canPause``, which stays `true` across a
    ///   stall.
    public var isPlaying: Bool {
        if case .playing = self {
            true
        } else {
            false
        }
    }

    /// Whether playback is stopped where it stands, for any reason.
    ///
    /// Read ``pauseReason`` to find out which.
    public var isPaused: Bool {
        if case .paused = self {
            true
        } else {
            false
        }
    }

    /// Whether a remote item is being held until a route appears.
    public var isWaitingForConnection: Bool {
        if case .waitingForConnection = self {
            true
        } else {
            false
        }
    }

    /// Whether the player has given up and will not move again without being told to.
    public var isFailed: Bool {
        if case .failed = self {
            true
        } else {
            false
        }
    }

    /// Whether the player holds an item and has neither stopped nor failed.
    ///
    /// This is the condition under which the audio session stays active, so a `false` here is
    /// where another app gets its turn.
    public var isActive: Bool {
        switch self {
        case .loading, .buffering, .playing, .paused, .waitingForConnection:
            true
        case .idle, .failed:
            false
        }
    }

    /// Whether the state is one worth showing a spinner for.
    ///
    /// Covers ``loading(_:)``, ``buffering(_:)`` and ``waitingForConnection(_:)`` — the states
    /// the player is expected to leave on its own. Prefer this to matching the three cases
    /// yourself.
    public var isTransient: Bool {
        isLoading || isBuffering || isWaitingForConnection
    }

    /// Whether calling ``AudioPlayer/play()`` would do something.
    ///
    /// - Note: Also `true` after a failure, where playing reloads the item from scratch rather
    ///   than resuming. `false` only while already playing, and while no item is loaded.
    public var canPlay: Bool {
        !isPlaying && item != nil
    }

    /// Whether calling ``AudioPlayer/pause()`` would do something.
    ///
    /// True while ``loading(_:)`` too, where the pause is recorded as intent and takes effect
    /// the moment the item becomes ready.
    public var canPause: Bool {
        isPlaying || isBuffering || isLoading
    }
}

/// Why sound stopped, which decides whether it may start again on its own.
///
/// Carried by ``PlaybackState/paused(_:reason:)`` and by ``AudioPlayerEvent/interrupted(_:)``.
public enum PauseReason: Sendable, Hashable, CaseIterable {
    /// The listener asked for silence.
    ///
    /// - Important: Nothing but another explicit ``AudioPlayer/play()`` resumes from here. The
    ///   player will not resume after an interruption ends or a connection returns while this
    ///   is the reason.
    case user

    /// A call, an alarm, or another app taking the audio session.
    ///
    /// Resumed automatically when the system advises it and
    /// ``AudioPlayerConfiguration/resumesAfterInterruption`` is `true`.
    case interruption

    /// An output device disappeared, such as headphones being unplugged.
    ///
    /// The system reports this separately from an interruption so that audio does not suddenly
    /// play out of the built-in speaker.
    case routeChange

    /// The connection came back but automatic resumption is switched off.
    ///
    /// Reached when a usable path returns while
    /// ``AudioPlayerConfiguration/resumesAfterConnectionLoss`` is `false`.
    case stalled

    /// Whether the pause was imposed rather than asked for.
    ///
    /// `true` for everything but ``user``. Only an automatic pause is eligible to be resumed
    /// by the player itself.
    public var isAutomatic: Bool {
        self != .user
    }
}

/// What the listener last asked for, which outlives any state the player passes through.
///
/// Intent is what makes a stall different from a pause: a track that stalls mid-playback keeps
/// an intent of ``play`` and so resumes by itself, while one the listener paused does not.
public enum PlaybackIntent: Sendable, Hashable {
    /// Sound is wanted, even during a stall the listener did not ask for.
    case play

    /// Silence is wanted, so nothing resumes on its own.
    case pause
}
