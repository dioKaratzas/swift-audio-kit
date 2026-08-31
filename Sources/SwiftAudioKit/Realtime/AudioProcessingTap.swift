//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if canImport(MediaToolbox) && !os(watchOS)
    import AudioToolbox
    import AVFoundation
    import MediaToolbox

    /// Builds the `AVAudioMix` that routes an item's audio through an effect chain.
    ///
    /// The tap's callbacks are C function pointers with no context of their own, so the chain is
    /// passed through `clientInfo` and recovered with `Unmanaged`. The retain taken here is
    /// balanced in the finalize callback, which is the only place it can be.
    enum AudioProcessingTap {
        /// Returns a mix that renders an item's audio through `chain`, or `nil` when this system
        /// cannot process it.
        ///
        /// A file or progressive download exposes an `AVAssetTrack` to attach to. A live stream
        /// and an HLS playlist expose none, and can only be tapped from the release that added
        /// `AVAudioMixInputParametersTrackMixID`, which taps the mix of all audio tracks.
        static func makeAudioMix(for asset: AVAsset, chain: AudioEffectChain) async -> AVAudioMix? {
            let track = try? await asset.loadTracks(withMediaType: .audio).first

            var callbacks = MTAudioProcessingTapCallbacks(
                version: kMTAudioProcessingTapCallbacksVersion_0,
                clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(chain).toOpaque()),
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
                    Unmanaged<AudioEffectChain>.fromOpaque(clientInfo).release()
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
        Unmanaged<AudioEffectChain>.fromOpaque(storage).release()
    }

    private func tapPrepare(
        tap: MTAudioProcessingTap,
        maxFrames: CMItemCount,
        processingFormat: UnsafePointer<AudioStreamBasicDescription>
    ) {
        chain(for: tap)?.prepare(for: tap, format: processingFormat.pointee, maximumFrames: Int(maxFrames))
    }

    private func tapUnprepare(tap: MTAudioProcessingTap) {
        chain(for: tap)?.teardown(for: tap)
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
        chain(for: tap)?.process(
            for: tap,
            buffers: UnsafeMutableAudioBufferListPointer(bufferListInOut),
            frames: Int(framesOut.pointee)
        )
    }

    private func chain(for tap: MTAudioProcessingTap) -> AudioEffectChain? {
        guard let storage = MTAudioProcessingTapGetStorage(tap) as UnsafeMutableRawPointer? else {
            return nil
        }
        return Unmanaged<AudioEffectChain>.fromOpaque(storage).takeUnretainedValue()
    }
#endif
