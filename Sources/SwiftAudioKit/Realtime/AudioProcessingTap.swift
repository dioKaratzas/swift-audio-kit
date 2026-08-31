//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if canImport(MediaToolbox) && !os(watchOS)
    import CoreAudio
    import AVFoundation
    import MediaToolbox

    /// Builds the `AVAudioMix` that routes an item's audio through an effect chain.
    ///
    /// The tap's callbacks are C function pointers with no context of their own, so the chain and
    /// the units to build a graph from travel through `clientInfo` as a ``TapContext`` and are
    /// recovered with `Unmanaged`. The retain taken here is balanced in the finalize callback,
    /// which is the only place it can be.
    enum AudioProcessingTap {
        /// Returns a mix that renders an item's audio through `chain`, or `nil` when this system
        /// cannot process it.
        ///
        /// A file or progressive download exposes an `AVAssetTrack` to attach to. A live stream
        /// and an HLS playlist expose none, and can only be tapped from the release that added
        /// `AVAudioMixInputParametersTrackMixID`, which taps the mix of all audio tracks.
        static func makeAudioMix(
            for asset: AVAsset,
            chain: AudioEffectChain,
            units: [AVAudioUnit]
        ) async -> AVAudioMix? {
            let track = try? await asset.loadTracks(withMediaType: .audio).first

            var callbacks = MTAudioProcessingTapCallbacks(
                version: kMTAudioProcessingTapCallbacksVersion_0,
                clientInfo: UnsafeMutableRawPointer(
                    Unmanaged.passRetained(TapContext(chain: chain, units: units)).toOpaque()
                ),
                init: tapInit,
                finalize: tapFinalize,
                prepare: tapPrepare,
                unprepare: tapUnprepare,
                process: tapProcess
            )

            /// Balances the retain taken above on every path that never reaches a tap, since
            /// the finalize callback that would otherwise balance it is never called.
            func abandon() -> AVAudioMix? {
                if let clientInfo = callbacks.clientInfo {
                    Unmanaged<TapContext>.fromOpaque(clientInfo).release()
                }
                return nil
            }

            var tap: MTAudioProcessingTap?
            let parameters: AVMutableAudioMixInputParameters

            if let track {
                let status = MTAudioProcessingTapCreate(
                    kCFAllocatorDefault,
                    &callbacks,
                    kMTAudioProcessingTapCreationFlag_PreEffects,
                    &tap
                )
                guard status == noErr, tap != nil else {
                    return abandon()
                }
                parameters = AVMutableAudioMixInputParameters(track: track)
            } else {
                #if compiler(>=6.4)
                    guard #available(macOS 27, iOS 27, tvOS 27, visionOS 27, *) else {
                        return abandon()
                    }
                    // Tapping the mix rather than one track leaves the processing format
                    // undefined, so one has to be asked for.
                    let status = MTAudioProcessingTapCreateWithPreferredFormat(
                        kCFAllocatorDefault,
                        &callbacks,
                        kMTAudioProcessingTapCreationFlag_PreEffects,
                        nil,
                        &tap
                    )
                    guard status == noErr, tap != nil else {
                        return abandon()
                    }
                    parameters = AVMutableAudioMixInputParameters()
                    parameters.trackID = AVAudioMixInputParametersTrackID.mixID.rawValue
                #else
                    return abandon()
                #endif
            }

            parameters.audioTapProcessor = tap

            let mix = AVMutableAudioMix()
            mix.inputParameters = [parameters]
            return mix
        }
    }

    private func tapInit(
        tap: MTAudioProcessingTap,
        clientInfo: UnsafeMutableRawPointer?,
        storage: UnsafeMutablePointer<UnsafeMutableRawPointer?>
    ) {
        storage.pointee = clientInfo
    }

    private func tapFinalize(tap: MTAudioProcessingTap) {
        guard let storage = MTAudioProcessingTapGetStorage(tap) as UnsafeMutableRawPointer? else {
            return
        }
        Unmanaged<TapContext>.fromOpaque(storage).release()
    }

    private func tapPrepare(
        tap: MTAudioProcessingTap,
        maxFrames: CMItemCount,
        processingFormat: UnsafePointer<AudioStreamBasicDescription>
    ) {
        guard let context = context(for: tap) else {
            return
        }
        context.chain.prepare(
            for: tap,
            units: context.units,
            format: processingFormat.pointee,
            maximumFrames: Int(maxFrames)
        )
    }

    private func tapUnprepare(tap: MTAudioProcessingTap) {
        context(for: tap)?.chain.teardown(for: tap)
    }

    private func tapProcess(
        tap: MTAudioProcessingTap,
        numberFrames: CMItemCount,
        flags: MTAudioProcessingTapFlags,
        bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
        framesOut: UnsafeMutablePointer<CMItemCount>,
        flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
    ) {
        let status = MTAudioProcessingTapGetSourceAudio(
            tap,
            numberFrames,
            bufferListInOut,
            flagsOut,
            nil,
            framesOut
        )
        guard status == noErr else {
            return
        }
        context(for: tap)?.chain.process(
            for: tap,
            buffers: UnsafeMutableAudioBufferListPointer(bufferListInOut),
            frames: Int(framesOut.pointee)
        )
    }

    /// What a tap carries: the chain to render through, and the units its graph is built from.
    /// Units are fixed when the tap is made, which is what keeps them off any shared state.
    private final class TapContext: Sendable {
        let chain: AudioEffectChain
        let units: [AVAudioUnit]

        init(chain: AudioEffectChain, units: [AVAudioUnit]) {
            self.chain = chain
            self.units = units
        }
    }

    private func context(for tap: MTAudioProcessingTap) -> TapContext? {
        guard let storage = MTAudioProcessingTapGetStorage(tap) as UnsafeMutableRawPointer? else {
            return nil
        }
        return Unmanaged<TapContext>.fromOpaque(storage).takeUnretainedValue()
    }
#endif
