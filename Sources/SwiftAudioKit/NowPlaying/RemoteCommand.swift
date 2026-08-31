//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// `skipForward` and `skipBackward` move by a fixed 15 seconds, which is not configurable.
public enum RemoteCommand: Sendable, Hashable, CaseIterable {
    /// Start playing, which on a failed item reloads it from scratch.
    case play

    /// Stop where it stands, keeping the item loaded.
    case pause

    /// The headphone-button gesture, which the system sends as one command.
    case togglePlayPause

    /// Unload and hand back the audio session.
    case stop

    /// Advance the queue, honouring repeat, shuffle and the skip set.
    case nextTrack

    /// Go back a track, which restarts the current one when there is nothing behind it.
    case previousTrack

    /// Jump 15 seconds ahead.
    case skipForward

    /// Jump 15 seconds back.
    case skipBackward

    /// Scrubbing on the lock screen, which is the only command carrying a position.
    case changePlaybackPosition
}

public extension Set where Element == RemoteCommand {
    /// Play, pause and track changes, for a queue with nothing to scrub.
    static var transport: Self {
        [.play, .pause, .togglePlayPause, .nextTrack, .previousTrack]
    }

    /// Transport plus scrubbing, which is what a new player registers.
    static var `default`: Self {
        transport.union([.changePlaybackPosition])
    }
}
