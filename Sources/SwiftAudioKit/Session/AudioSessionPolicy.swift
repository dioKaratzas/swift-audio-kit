//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// Inert on macOS, which has no audio session to configure.
public struct AudioSessionPolicy: Sendable, Hashable {
    /// Whether the player configures and activates the session, or leaves it to the app.
    /// The three options below do nothing when this is `false`.
    public var isManaged: Bool

    /// Lets other apps keep playing alongside, at the cost of never interrupting them.
    public var mixesWithOthers: Bool

    /// Quietens other apps rather than silencing them, for spoken interjections.
    public var ducksOthers: Bool

    /// Allows interrupting podcasts and audiobooks, which are otherwise left alone.
    public var interruptsSpokenAudio: Bool

    /// Defaults to taking the session over, which is what a music player wants.
    public init(
        isManaged: Bool = true,
        mixesWithOthers: Bool = false,
        ducksOthers: Bool = false,
        interruptsSpokenAudio: Bool = false
    ) {
        self.isManaged = isManaged
        self.mixesWithOthers = mixesWithOthers
        self.ducksOthers = ducksOthers
        self.interruptsSpokenAudio = interruptsSpokenAudio
    }

    /// Long-form playback that takes over the session, which is what a music player wants.
    public static let managed = AudioSessionPolicy()

    /// Leaves the session entirely alone, for apps that configure it themselves.
    public static let unmanaged = AudioSessionPolicy(isManaged: false)

    /// Plays over whatever else is running, for sound effects and short cues.
    public static let mixing = AudioSessionPolicy(mixesWithOthers: true)
}
