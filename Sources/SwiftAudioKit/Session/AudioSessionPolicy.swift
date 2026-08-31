//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public struct AudioSessionPolicy: Sendable, Hashable {
    /// Whether the player configures and activates the session, or leaves it to the app.
    public var isManaged: Bool
    public var mixesWithOthers: Bool
    public var ducksOthers: Bool
    public var interruptsSpokenAudio: Bool

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

    public static let mixing = AudioSessionPolicy(mixesWithOthers: true)
}
