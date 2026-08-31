//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public enum PlaybackState: Sendable, Hashable {
    case idle
    case loading(AudioItem)
    case buffering(AudioItem)
    case playing(AudioItem)
    case paused(AudioItem, reason: PauseReason)
    case waitingForConnection(AudioItem)
    case failed(item: AudioItem?, error: AudioPlayerError)

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

    public var error: AudioPlayerError? {
        guard case let .failed(_, error) = self else {
            return nil
        }
        return error
    }

    public var pauseReason: PauseReason? {
        guard case let .paused(_, reason) = self else {
            return nil
        }
        return reason
    }

    public var isIdle: Bool {
        self == .idle
    }

    public var isLoading: Bool {
        if case .loading = self {
            true
        } else {
            false
        }
    }

    public var isBuffering: Bool {
        if case .buffering = self {
            true
        } else {
            false
        }
    }

    public var isPlaying: Bool {
        if case .playing = self {
            true
        } else {
            false
        }
    }

    public var isPaused: Bool {
        if case .paused = self {
            true
        } else {
            false
        }
    }

    public var isWaitingForConnection: Bool {
        if case .waitingForConnection = self {
            true
        } else {
            false
        }
    }

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

    public var canPlay: Bool {
        !isPlaying && item != nil
    }

    public var canPause: Bool {
        isPlaying || isBuffering || isLoading
    }
}

public enum PauseReason: Sendable, Hashable, CaseIterable {
    case user
    case interruption
    case routeChange
    case stalled

    /// Everything the listener did not ask for, and so may be resumed automatically.
    public var isAutomatic: Bool {
        self != .user
    }
}

public enum PlaybackIntent: Sendable, Hashable {
    case play
    case pause
}
