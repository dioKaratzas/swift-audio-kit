//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if canImport(AVFAudio) && !os(watchOS)
    import AVFAudio
    import Observation

    /// The audio units the player routes playback through.
    ///
    /// Reach it through ``AudioPlayer/audioProcessing``. Hand it any `AVAudioUnit` — an
    /// equalizer, a reverb, a compressor, a distortion, an AUv3 of your own — and the player
    /// renders the stream through them in order before it reaches the output:
    ///
    ///     let equalizer = AVAudioUnitEQ(numberOfBands: 10)
    ///     player.audioProcessing.units = [equalizer]
    ///
    /// Keep your own reference to a unit and change its parameters whenever you like. They are
    /// safe to set while audio is rendering and take effect immediately, with no reload and no
    /// gap:
    ///
    ///     equalizer.bands[0].frequency = 60
    ///     equalizer.bands[0].gain = 6
    ///
    /// Playback is rendered by an `AVAudioEngine` fed from the player's stream, so anything that
    /// engine can host works: `AVAudioUnitReverb`, `AVAudioUnitDelay`, `AVAudioUnitDistortion`,
    /// `AVAudioUnitEQ`, and any Audio Unit you load yourself with
    /// `AVAudioUnit.instantiate(with:options:)`.
    ///
    /// - Important: Replacing ``units`` rebuilds the render graph, which is why it takes effect
    ///   on the next item rather than the one playing. Reach for a unit's own `bypass` to turn
    ///   an effect off in place.
    /// - Important: An `AVAudioUnitTimeEffect` — `AVAudioUnitTimePitch` and
    ///   `AVAudioUnitVarispeed` — is ignored, and logs an error when assigned. Every block the
    ///   player hands over has to come back the same length, and a time effect by definition
    ///   returns a different one. Use ``AudioPlayer/rate`` to change speed.
    /// - Important: Not every stream can be processed. A local file and a progressive download
    ///   always can. A live stream and an HLS playlist expose no audio track, and can only be
    ///   processed from macOS 27, iOS 27, tvOS 27 and visionOS 27, which can tap the mix of all
    ///   audio tracks instead. ``isAvailable`` reports what the item playing can do.
    /// - Note: There is no audio processing on watchOS, which has neither the audio units nor
    ///   the MediaToolbox framework the tap lives in. The whole type is absent there.
    @Observable
    @MainActor
    public final class AudioProcessing {
        /// The units the stream is rendered through, in order.
        ///
        /// Empty by default, which routes audio straight through. Units are connected
        /// first-to-last, so `[equalizer, reverb]` equalizes and then reverberates.
        ///
        /// - Note: Takes effect on the next item. Changing a unit's own parameters takes
        ///   effect immediately.
        public var units = [AVAudioUnit]() {
            didSet { onChange?(Self.rendered(from: units)) }
        }

        /// Whether the item playing is being rendered through ``units``.
        ///
        /// `false` when nothing is playing, and `false` before macOS 27, iOS 27, tvOS 27 and
        /// visionOS 27 for a live or HLS stream, which exposes no audio track to attach a
        /// processor to. Resolved when an item loads, so check it once playback has started.
        public private(set) var isAvailable = false

        @ObservationIgnored var onChange: (@MainActor ([AVAudioUnit]) -> Void)?

        /// Creates an empty chain, which routes audio straight through.
        public init() {}

        /// Drops what the render graph cannot host, so one unusable unit does not cost the
        /// caller the whole chain.
        private static func rendered(from units: [AVAudioUnit]) -> [AVAudioUnit] {
            units.filter { unit in
                guard unit is AVAudioUnitTimeEffect else {
                    return true
                }
                Log.emit(
                    .engine,
                    .error,
                    "\(type(of: unit)) changes the length of a block, which playback cannot do; ignoring it"
                )
                return false
            }
        }

        func setAvailable(_ available: Bool) {
            guard available != isAvailable else {
                return
            }
            isAvailable = available
        }
    }
#endif
