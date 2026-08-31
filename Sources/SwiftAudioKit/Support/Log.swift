//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import os

/// Messages are filterable with `log stream --predicate 'subsystem == "com.swiftaudiokit"'`,
/// and silenced entirely with `log config --subsystem com.swiftaudiokit --mode level:off`.
enum Log {
    static let player = Logger(subsystem: subsystem, category: "player")
    static let engine = Logger(subsystem: subsystem, category: "engine")
    static let session = Logger(subsystem: subsystem, category: "session")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let nowPlaying = Logger(subsystem: subsystem, category: "nowPlaying")

    private static let subsystem = "com.swiftaudiokit"
}

extension PlaybackState {
    /// Safe to log: names the case without the track it carries.
    var logDescription: String {
        switch self {
        case .idle: "idle"
        case .loading: "loading"
        case .buffering: "buffering"
        case .playing: "playing"
        case let .paused(_, reason): "paused(\(reason))"
        case .waitingForConnection: "waitingForConnection"
        case let .failed(_, error): "failed(\(error.logDescription))"
        }
    }
}

extension AudioPlayerError {
    var logDescription: String {
        switch self {
        case let .retryLimitReached(attempts): "retryLimitReached(\(attempts))"
        case let .playbackFailed(failure): "playbackFailed(\(failure.domain) \(failure.code))"
        case let .connectionLost(after): "connectionLost(after: \(after))"
        case .itemUnavailable: "itemUnavailable"
        case .noPlayableItems: "noPlayableItems"
        case let .audioSessionFailed(failure): "audioSessionFailed(\(failure.domain) \(failure.code))"
        }
    }
}
