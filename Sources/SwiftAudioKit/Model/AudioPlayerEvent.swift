//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// Cases that name an item carry its id, because one can land after the listener has moved on.
public enum AudioPlayerEvent: Sendable, Hashable {
    /// The same transition the observable `state` publishes, for consumers not observing it.
    case stateChanged(from: PlaybackState, to: PlaybackState)

    /// A different track took over; `to` is `nil` only when the queue emptied.
    case itemChanged(from: AudioItem?, to: AudioItem?)

    /// A track reached its end on its own, rather than being skipped.
    case itemFinished(AudioItem)

    /// Nothing left to advance to, after which the player stops.
    case queueExhausted

    /// A length arrived from the engine, which never happens for a live stream.
    case durationResolved(Duration, for: AudioItem.ID)

    /// The merged metadata changed, carrying the whole of it rather than the delta.
    case metadataUpdated(AudioMetadata, for: AudioItem.ID)

    /// The rung changed, by request or by the automatic policy stepping up or down.
    case qualityChanged(from: AudioQuality, to: AudioQuality)

    /// A new network path was reported, usable or not.
    case networkChanged(NetworkStatus)

    /// Something outside the app took the session or the output route.
    case interrupted(PauseReason)

    /// The interruption is over; `shouldResume` is the system's advice, not a promise.
    case interruptionEnded(shouldResume: Bool)

    /// Playback carried on: a note from the engine's error log, not a failure.
    case recoverableErrorLogged(PlaybackFailure)

    /// Playback stopped and will not resume without being told to.
    case failed(AudioPlayerError)
}
