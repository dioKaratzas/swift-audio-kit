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

extension Log {
    /// Effects are the complete list of what the player does, so recording them here keeps
    /// coverage exhaustive as new ones are added.
    static func record(_ effect: Effect) {
        switch effect {
        case .load, .unload, .play, .pause:
            engine.debug("\(effect.name, privacy: .public)")

        case let .seek(time, generation):
            engine.debug("seek to \(time.totalSeconds, privacy: .public)s generation \(generation)")

        case .activateSession, .deactivateSession, .beginBackgroundActivity, .endBackgroundActivity:
            session.debug("\(effect.name, privacy: .public)")

        case let .scheduleRetry(after, _):
            player.notice("retrying in \(after.totalSeconds, privacy: .public)s")

        case let .startConnectionLossTimer(deadline, _):
            player.notice("waiting up to \(deadline.totalSeconds, privacy: .public)s for the connection")

        case .cancelRetry, .cancelConnectionLossTimer, .scheduleQualityUpgrade:
            player.debug("\(effect.name, privacy: .public)")

        case .emit:
            break
        }
    }

    static func record(_ event: AudioPlayerEvent) {
        switch event {
        case let .qualityChanged(from, to):
            player.notice("quality \(from.name, privacy: .public) → \(to.name, privacy: .public)")
        case .queueExhausted:
            player.notice("queue exhausted")
        case .itemChanged:
            player.notice("item changed")
        case let .interrupted(reason):
            player.notice("interrupted by \(String(describing: reason), privacy: .public)")
        case let .interruptionEnded(shouldResume):
            player.notice("interruption ended, resume \(shouldResume, privacy: .public)")
        case let .failed(error):
            player.error("failed: \(error.logDescription, privacy: .public)")
        case let .recoverableErrorLogged(failure):
            engine.debug("recovered from \(failure.domain, privacy: .public) \(failure.code)")
        case .itemFinished:
            player.debug("item finished")
        case let .durationResolved(duration, _):
            engine.debug("duration \(duration.totalSeconds, privacy: .public)s")
        case .metadataUpdated:
            engine.debug("metadata updated")
        case .stateChanged, .networkChanged:
            break
        }
    }
}

private extension Effect {
    var name: String {
        switch self {
        case .load: "load"
        case .unload: "unload"
        case .play: "play"
        case .pause: "pause"
        case .seek: "seek"
        case .activateSession: "activate session"
        case .deactivateSession: "deactivate session"
        case .beginBackgroundActivity: "begin background activity"
        case .endBackgroundActivity: "end background activity"
        case .scheduleRetry: "schedule retry"
        case .cancelRetry: "cancel retry"
        case .startConnectionLossTimer: "start connection timer"
        case .cancelConnectionLossTimer: "cancel connection timer"
        case .scheduleQualityUpgrade: "schedule quality upgrade"
        case .emit: "emit"
        }
    }
}

private extension AudioQuality {
    var name: String {
        switch self {
        case .low: "low"
        case .medium: "medium"
        case .high: "high"
        }
    }
}
