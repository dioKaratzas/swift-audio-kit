//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if canImport(AVFAudio) && !os(macOS)
    import AVFAudio
#endif

/// Serialises session changes, because activating is a blocking call and two overlapping
/// activate/deactivate pairs corrupt the session.
actor AudioSessionController {
    private var policy: AudioSessionPolicy
    private var isActive = false

    init(policy: AudioSessionPolicy = .managed) {
        self.policy = policy
    }

    func update(policy: AudioSessionPolicy) {
        self.policy = policy
    }

    func activate() throws(AudioPlayerError) {
        guard policy.isManaged, !isActive else {
            return
        }
        try configure()
        try setActive(true)
        isActive = true
    }

    func deactivate() throws(AudioPlayerError) {
        guard policy.isManaged, isActive else {
            return
        }
        isActive = false
        try setActive(false)
    }

    #if canImport(AVFAudio) && !os(macOS)
        private func configure() throws(AudioPlayerError) {
            do {
                try AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .default,
                    policy: .longFormAudio,
                    options: options
                )
            } catch {
                throw .audioSessionFailed(PlaybackFailure(error))
            }
        }

        private func setActive(_ active: Bool) throws(AudioPlayerError) {
            do {
                try AVAudioSession.sharedInstance().setActive(active, options: .notifyOthersOnDeactivation)
            } catch {
                throw .audioSessionFailed(PlaybackFailure(error))
            }
        }

        /// The Bluetooth options are fixed for output-only categories, so setting them is inert.
        private var options: AVAudioSession.CategoryOptions {
            var options: AVAudioSession.CategoryOptions = []
            if policy.mixesWithOthers {
                options.insert(.mixWithOthers)
            }
            if policy.ducksOthers {
                options.insert(.duckOthers)
            }
            if policy.interruptsSpokenAudio {
                options.insert(.interruptSpokenAudioAndMixWithOthers)
            }
            return options
        }

    #else
        private func configure() throws(AudioPlayerError) {}

        private func setActive(_ active: Bool) throws(AudioPlayerError) {}
    #endif
}
