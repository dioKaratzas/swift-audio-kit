//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// Something that happened at a point in time, delivered on ``AudioPlayer/events``.
///
/// Observation covers what is true now; events cover what just occurred and leaves no trace
/// in the state — a track finishing, the queue running out, an error the engine recovered
/// from on its own.
///
/// - Note: Cases that concern a particular track carry its ``AudioItem/id``, because an event
///   can be handled after the listener has already moved on. Compare it against
///   ``AudioPlayer/currentItem`` before acting.
public enum AudioPlayerEvent: Sendable, Hashable {
    /// The player moved from one state to another.
    ///
    /// The same transition ``AudioPlayer/state`` publishes, offered here for code outside the
    /// observation graph and for anything that needs the previous state as well as the new
    /// one.
    case stateChanged(from: PlaybackState, to: PlaybackState)

    /// A different track took over.
    ///
    /// Emitted whenever the loaded track changes: advancing, retreating, jumping to a queued
    /// track, or the current track being removed. `to` is `nil` only when the queue emptied,
    /// and `from` is `nil` for the first track of a session.
    case itemChanged(from: AudioItem?, to: AudioItem?)

    /// A track reached its end on its own.
    ///
    /// Not emitted when a track is skipped, removed, or cut short by a failure, so this is
    /// the case to count a play against.
    case itemFinished(AudioItem)

    /// There is nothing left to advance to, and the player has stopped.
    ///
    /// Emitted when ``AudioPlayer/next()`` runs off the end under ``RepeatMode/off``, and
    /// when the last track finishes. Never emitted under ``RepeatMode/all`` or
    /// ``RepeatMode/one``, which never run out.
    case queueExhausted

    /// A length arrived from the engine for the named track.
    ///
    /// - Note: This never fires for a live stream, which reports no duration. Waiting on it
    ///   before drawing a progress bar waits forever; check ``PlaybackProgress/isLive``.
    case durationResolved(Duration, for: AudioItem.ID)

    /// The merged metadata changed for the named track.
    ///
    /// Carries the whole of the metadata rather than the delta, already merged so that the
    /// item's own fields outrank the stream's. The same value is published on
    /// ``AudioPlayer/metadata``.
    case metadataUpdated(AudioMetadata, for: AudioItem.ID)

    /// The quality rung changed.
    ///
    /// Emitted both for ``AudioPlayer/setQuality(_:)`` and for the automatic policy stepping
    /// down after repeated stalls or back up after a clean stretch.
    case qualityChanged(from: AudioQuality, to: AudioQuality)

    /// A new network path was reported, usable or not.
    ///
    /// The same value is published on ``AudioPlayer/network``.
    case networkChanged(NetworkStatus)

    /// Something outside the app took the audio session or the output route.
    ///
    /// The associated ``PauseReason`` says which. Playback is already paused by the time this
    /// arrives.
    case interrupted(PauseReason)

    /// An interruption finished.
    ///
    /// - Important: `shouldResume` is the system's advice, not a promise, and not a report of
    ///   what the player did. The player resumes only when the system advises it,
    ///   ``AudioPlayerConfiguration/resumesAfterInterruption`` is `true`, and the listener had
    ///   not already asked for silence.
    case interruptionEnded(shouldResume: Bool)

    /// The engine logged an error it recovered from.
    ///
    /// Playback carried on. Treat this as a diagnostic rather than something to show a
    /// listener; a failure that actually stopped playback arrives as ``failed(_:)``.
    case recoverableErrorLogged(PlaybackFailure)

    /// Playback stopped and will not resume without being told to.
    ///
    /// The player is now in ``PlaybackState/failed(item:error:)`` carrying the same error.
    /// Check ``AudioPlayerError/isRetryable`` to decide whether to offer a retry.
    case failed(AudioPlayerError)
}
