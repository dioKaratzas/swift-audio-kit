//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// A control the system offers on the lock screen, in Control Center, and on accessories.
///
/// Pass the set you want to ``AudioPlayer/init(configuration:remoteCommands:)``. The player
/// registers exactly those with `MPRemoteCommandCenter`, disables the rest, and handles each
/// one itself, so there is no callback to write. Register only what your app can honour: a
/// registered command that does nothing is worse than an absent one, because the system draws
/// the control either way.
///
/// - Note: ``skipForward`` and ``skipBackward`` move by a fixed 15 seconds. That interval is
///   not configurable; use ``AudioPlayer/seek(by:)`` for a step of your own.
public enum RemoteCommand: Sendable, Hashable, CaseIterable {
    /// Start playing, which on a failed item reloads it from scratch.
    ///
    /// Maps to ``AudioPlayer/play()``.
    case play

    /// Stop where it stands, keeping the item loaded.
    ///
    /// Records that the listener wants silence, so nothing resumes on its own afterwards.
    /// Maps to ``AudioPlayer/pause()``.
    case pause

    /// The headphone-button gesture, which the system sends as a single command.
    ///
    /// Register this alongside ``play`` and ``pause``: some accessories send only the toggle,
    /// others only the explicit pair. Maps to ``AudioPlayer/togglePlayPause()``.
    case togglePlayPause

    /// Unload the item and hand back the audio session.
    ///
    /// Distinct from ``pause``, which keeps both. Maps to ``AudioPlayer/stop()``.
    case stop

    /// Advance the queue, honouring repeat, shuffle and ``AudioPlayer/skippedItems``.
    ///
    /// Maps to ``AudioPlayer/next()``.
    case nextTrack

    /// Go back a track, restarting the current one when there is nothing behind it.
    ///
    /// Maps to ``AudioPlayer/previous()``.
    case previousTrack

    /// Jump 15 seconds ahead.
    ///
    /// The interval is fixed and is reported to the system so the control is drawn with the
    /// right numeral.
    case skipForward

    /// Jump 15 seconds back.
    ///
    /// The interval is fixed and is reported to the system so the control is drawn with the
    /// right numeral.
    case skipBackward

    /// Scrubbing on the lock screen, which is the only command carrying a position.
    ///
    /// The player seeks to the position, clamped into the seekable range. Leave it out for a
    /// live stream with nothing to scrub.
    case changePlaybackPosition
}

public extension Set where Element == RemoteCommand {
    /// Play, pause and track changes, for a queue with nothing to scrub.
    ///
    /// Contains ``RemoteCommand/play``, ``RemoteCommand/pause``,
    /// ``RemoteCommand/togglePlayPause``, ``RemoteCommand/nextTrack`` and
    /// ``RemoteCommand/previousTrack``. A sensible choice for live radio, where a scrubber
    /// would suggest a timeline the stream does not have.
    static var transport: Self {
        [.play, .pause, .togglePlayPause, .nextTrack, .previousTrack]
    }

    /// Transport plus scrubbing, which is what a new player registers.
    ///
    /// ``transport`` together with ``RemoteCommand/changePlaybackPosition``.
    static var `default`: Self {
        transport.union([.changePlaybackPosition])
    }
}
