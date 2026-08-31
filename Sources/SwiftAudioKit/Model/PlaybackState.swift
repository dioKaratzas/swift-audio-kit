//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// What the player is doing right now, carrying the track it is doing it to.
public enum PlaybackState: Sendable, Hashable {
    /// Nothing is loaded and the audio session has been handed back.
    case idle

    /// An item has been handed to the engine, which has not reported it ready yet.
    case loading(AudioItem)

    /// Playback has stalled for data, or is being retried after a failure.
    case buffering(AudioItem)

    /// Sound is coming out.
    case playing(AudioItem)

    /// Stopped where it stands, with the reason it stopped.
    case paused(AudioItem, reason: PauseReason)

    /// Holding a remote item until a route appears, up to the configured deadline.
    case waitingForConnection(AudioItem)

    /// Given up on the item, which is `nil` when the failure came before one was chosen.
    case failed(item: AudioItem?, error: AudioPlayerError)

    /// The track this state concerns, or `nil` when idle or failed before choosing one.
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

    /// Set only while failed.
    public var error: AudioPlayerError? {
        guard case let .failed(_, error) = self else {
            return nil
        }
        return error
    }

    /// Set only while paused.
    public var pauseReason: PauseReason? {
        guard case let .paused(_, reason) = self else {
            return nil
        }
        return reason
    }

    /// Nothing loaded, which is where the player both starts and stops.
    public var isIdle: Bool {
        self == .idle
    }

    /// Waiting on the engine to accept an item it has been handed.
    public var isLoading: Bool {
        if case .loading = self {
            true
        } else {
            false
        }
    }

    /// Stalled for data mid-track, or waiting out a retry.
    public var isBuffering: Bool {
        if case .buffering = self {
            true
        } else {
            false
        }
    }

    /// Sound is coming out, as distinct from merely intending to play.
    public var isPlaying: Bool {
        if case .playing = self {
            true
        } else {
            false
        }
    }

    /// Stopped where it stands, for any reason.
    public var isPaused: Bool {
        if case .paused = self {
            true
        } else {
            false
        }
    }

    /// Holding a remote item until a route appears.
    public var isWaitingForConnection: Bool {
        if case .waitingForConnection = self {
            true
        } else {
            false
        }
    }

    /// Given up, and will not move again without being told to.
    public var isFailed: Bool {
        if case .failed = self {
            true
        } else {
            false
        }
    }

    /// Holds an item and has not stopped or failed, so the audio session should stay active.
    public var isActive: Bool {
        switch self {
        case .loading, .buffering, .playing, .paused, .waitingForConnection:
            true
        case .idle, .failed:
            false
        }
    }

    /// Worth showing a spinner for.
    public var isTransient: Bool {
        isLoading || isBuffering || isWaitingForConnection
    }

    /// Also true after a failure, where playing again reloads the item from scratch.
    public var canPlay: Bool {
        !isPlaying && item != nil
    }

    /// True while loading too, where pausing takes effect the moment the item is ready.
    public var canPause: Bool {
        isPlaying || isBuffering || isLoading
    }
}

/// Why sound stopped, which decides whether it may start again on its own.
public enum PauseReason: Sendable, Hashable, CaseIterable {
    /// The listener asked, so nothing may resume it but the listener.
    case user

    /// A call, an alarm, or another app taking the session.
    case interruption

    /// Headphones unplugged, or another output disappearing.
    case routeChange

    /// The connection came back but automatic resumption is switched off.
    case stalled

    /// Everything the listener did not ask for, and so may be resumed automatically.
    public var isAutomatic: Bool {
        self != .user
    }
}

/// What the listener last asked for, which outlives any state the player passes through.
public enum PlaybackIntent: Sendable, Hashable {
    /// Sound is wanted, even during a stall the listener did not ask for.
    case play

    /// Silence is wanted, so nothing resumes on its own.
    case pause
}
