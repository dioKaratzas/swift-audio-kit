//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// Whether the player owns the audio session, and how it shares the output with other apps.
///
/// The player activates the session when a track starts and deactivates it when playback
/// stops, configuring the `playback` category with the `longFormAudio` policy. Set this
/// through ``AudioPlayerConfiguration/audioSession``.
///
/// - Note: There is no audio session on macOS, so every option here is inert on that platform.
///   The type stays available so shared code needs no `#if` of its own.
public struct AudioSessionPolicy: Sendable, Hashable {
    /// Whether the player configures and activates the audio session.
    ///
    /// - Important: The three options below do nothing while this is `false`. Set it to
    ///   `false` only if your app configures `AVAudioSession` itself; the player will then
    ///   never activate or deactivate it, and a conflict with another app surfaces as silence
    ///   rather than as an ``AudioPlayerError/audioSessionFailed(_:)``.
    public var isManaged: Bool

    /// Whether other apps may keep playing alongside this one.
    ///
    /// Sets `AVAudioSession.CategoryOptions.mixWithOthers`. The cost is that this player can
    /// then never interrupt anything, so background music continues over your audio.
    public var mixesWithOthers: Bool

    /// Whether other apps are quietened rather than silenced.
    ///
    /// Sets `AVAudioSession.CategoryOptions.duckOthers`. Meant for short spoken interjections
    /// over someone else's music.
    public var ducksOthers: Bool

    /// Whether spoken-audio apps may be interrupted.
    ///
    /// Sets `AVAudioSession.CategoryOptions.interruptSpokenAudioAndMixWithOthers`. Podcast and
    /// audiobook apps are otherwise left alone by the system, on the assumption that
    /// interrupting speech loses the listener's place.
    public var interruptsSpokenAudio: Bool

    /// Creates a policy.
    ///
    /// - Parameters:
    ///   - isManaged: Whether the player owns the session. Defaults to `true`. When `false`,
    ///     the remaining arguments have no effect.
    ///   - mixesWithOthers: Whether other apps keep playing alongside. Defaults to `false`,
    ///     which is what a music player wants.
    ///   - ducksOthers: Whether other apps are quietened rather than silenced. Defaults to
    ///     `false`.
    ///   - interruptsSpokenAudio: Whether podcast and audiobook apps may be interrupted.
    ///     Defaults to `false`.
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

    /// Long-form playback that takes the session over, which is what a music player wants.
    ///
    /// The default for ``AudioPlayerConfiguration/audioSession``.
    public static let managed = AudioSessionPolicy()

    /// Leaves the audio session entirely alone, for apps that configure it themselves.
    ///
    /// Also the right choice when several players share a process and one place should
    /// arbitrate between them.
    public static let unmanaged = AudioSessionPolicy(isManaged: false)

    /// Plays over whatever else is running, for sound effects and short cues.
    ///
    /// Interrupting the listener's music would be the wrong trade for audio this brief.
    public static let mixing = AudioSessionPolicy(mixesWithOthers: true)
}
