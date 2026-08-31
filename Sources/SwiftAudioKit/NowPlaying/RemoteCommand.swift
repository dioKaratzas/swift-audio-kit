//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public enum RemoteCommand: Sendable, Hashable, CaseIterable {
    case play
    case pause
    case togglePlayPause
    case stop
    case nextTrack
    case previousTrack
    case skipForward
    case skipBackward
    case changePlaybackPosition
}

public extension Set where Element == RemoteCommand {
    static var transport: Self {
        [.play, .pause, .togglePlayPause, .nextTrack, .previousTrack]
    }

    static var `default`: Self {
        transport.union([.changePlaybackPosition])
    }
}
