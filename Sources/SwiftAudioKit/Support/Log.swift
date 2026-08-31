//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import os
import Synchronization

/// The one knob on the library's logging.
///
/// SwiftAudioKit writes to the unified log under the `com.swiftaudiokit` subsystem, with
/// separate categories for the player, the engine, the audio session, the network monitor and
/// Now Playing. Filter a live session with
/// `log stream --predicate 'subsystem == "com.swiftaudiokit"'`. This type only decides how
/// much of that is produced in the first place.
public enum AudioPlayerLog {
    /// How much detail the library writes to the unified log.
    ///
    /// Mirrors the unified log's own levels, which have no `trace` or `warning`.
    public enum Level: Int, Sendable, Hashable, CaseIterable, Comparable {
        /// Every effect and engine signal.
        ///
        /// A line or more per second while playing. The default, because the unified log keeps
        /// debug messages in memory rather than writing them to disk.
        case debug

        /// Unused by the library itself.
        ///
        /// Nothing is emitted at this level, so selecting it silences everything below
        /// ``notice`` in practice.
        case info

        /// State changes, retries and quality shifts: the shape of a session.
        ///
        /// The level to choose when you want to see what a player did without the per-tick
        /// detail of ``debug``.
        case notice

        /// Only what stopped playback.
        case error

        /// Nothing at all.
        ///
        /// Selecting this silences every category, including the messages that would otherwise
        /// have been built.
        case off

        /// Returns a Boolean value indicating whether one level is more verbose than another.
        ///
        /// Orders the levels upwards from ``debug``, so ``off`` compares highest.
        ///
        /// - Parameters:
        ///   - lhs: The level to compare on the left.
        ///   - rhs: The level to compare against.
        /// - Returns: `true` when `lhs` admits more messages than `rhs`.
        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The lowest level the library emits. Defaults to ``Level/debug``.
    ///
    /// - Important: A message below this level is never *built*, not merely discarded: the
    ///   text is produced behind an autoclosure that the level check short-circuits. Raising
    ///   the level therefore costs nothing at the call site, and there is no reason to guard
    ///   playback code against logging overhead yourself.
    /// - Note: Safe to set from any thread and at any time, including while a player is
    ///   running. The change applies to the next message.
    public static var level: Level {
        get { Level(rawValue: storage.load(ordering: .relaxed)) ?? .debug }
        set { storage.store(newValue.rawValue, ordering: .relaxed) }
    }

    private static let storage = Atomic<Int>(Level.debug.rawValue)
}

/// Messages are filterable with `log stream --predicate 'subsystem == "com.swiftaudiokit"'`.
enum Log {
    enum Category: String {
        case player
        case engine
        case session
        case network
        case nowPlaying
    }

    static func emit(_ category: Category, _ level: AudioPlayerLog.Level, _ message: @autoclosure () -> String) {
        guard level != .off, level >= AudioPlayerLog.level else {
            return
        }
        let logger = logger(for: category)
        let text = message()

        switch level {
        case .debug: logger.debug("\(text, privacy: .public)")
        case .info: logger.info("\(text, privacy: .public)")
        case .notice: logger.notice("\(text, privacy: .public)")
        case .error: logger.error("\(text, privacy: .public)")
        case .off: break
        }
    }

    private static func logger(for category: Category) -> Logger {
        switch category {
        case .player: player
        case .engine: engine
        case .session: session
        case .network: network
        case .nowPlaying: nowPlaying
        }
    }

    private static let subsystem = "com.swiftaudiokit"
    private static let player = Logger(subsystem: subsystem, category: Category.player.rawValue)
    private static let engine = Logger(subsystem: subsystem, category: Category.engine.rawValue)
    private static let session = Logger(subsystem: subsystem, category: Category.session.rawValue)
    private static let network = Logger(subsystem: subsystem, category: Category.network.rawValue)
    private static let nowPlaying = Logger(subsystem: subsystem, category: Category.nowPlaying.rawValue)
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
            emit(.engine, .debug, effect.name)

        case let .seek(time, generation):
            emit(.engine, .debug, "seek to \(time.totalSeconds)s generation \(generation)")

        case .activateSession, .deactivateSession, .beginBackgroundActivity, .endBackgroundActivity:
            emit(.session, .debug, effect.name)

        case let .scheduleRetry(after, _):
            emit(.player, .notice, "retrying in \(after.totalSeconds)s")

        case let .startConnectionLossTimer(deadline, _):
            emit(.player, .notice, "waiting up to \(deadline.totalSeconds)s for the connection")

        case .cancelRetry, .cancelConnectionLossTimer, .scheduleQualityUpgrade:
            emit(.player, .debug, effect.name)

        case .emit:
            break
        }
    }

    static func record(_ event: AudioPlayerEvent) {
        switch event {
        case let .qualityChanged(from, to):
            emit(.player, .notice, "quality \(from.name) → \(to.name)")
        case .queueExhausted:
            emit(.player, .notice, "queue exhausted")
        case .itemChanged:
            emit(.player, .notice, "item changed")
        case let .interrupted(reason):
            emit(.player, .notice, "interrupted by \(reason)")
        case let .interruptionEnded(shouldResume):
            emit(.player, .notice, "interruption ended, resume \(shouldResume)")
        case let .failed(error):
            emit(.player, .error, "failed: \(error.logDescription)")
        case let .recoverableErrorLogged(failure):
            emit(.engine, .debug, "recovered from \(failure.domain) \(failure.code)")
        case .itemFinished:
            emit(.player, .debug, "item finished")
        case let .durationResolved(duration, _):
            emit(.engine, .debug, "duration \(duration.totalSeconds)s")
        case .metadataUpdated:
            emit(.engine, .debug, "metadata updated")
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
