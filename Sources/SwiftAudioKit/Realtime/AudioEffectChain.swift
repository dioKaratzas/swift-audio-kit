//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if canImport(MediaToolbox) && !os(watchOS)
    import CoreAudio
    import AVFoundation
    import MediaToolbox
    import Synchronization

    /// Renders an item's audio through a caller-supplied chain of audio units.
    ///
    /// One chain serves every item the engine plays, and each item's tap claims it in turn.
    /// Claiming matters because the taps overlap: replacing an item starts the new tap before
    /// the old one is torn down, and without an owner the old tap's teardown would stop a graph
    /// the new one is already rendering through. `owner` is the tap that last prepared the
    /// chain, and only that tap is allowed to render or tear down.
    ///
    /// The processing callback is hard realtime: it cannot allocate, lock, or await. The graph is
    /// built in `prepare`, off the realtime thread, and only rendered afterwards. Each tap carries
    /// the units it was built with, so nothing here is shared mutable state. Audio units are
    /// sendable and their parameters are safe to set from another thread, which is how a caller's
    /// live changes cross over without a lock.
    final class AudioEffectChain: @unchecked Sendable {
        private let engine = AVAudioEngine()
        private let owner = Atomic<UInt>(0)
        private var attachedUnits = [AVAudioUnit]()
        private var sourceBuffer: UnsafeMutableAudioBufferListPointer?

        // MARK: Tap lifecycle

        /// Builds the render graph and hands the chain to `tap`. Called before any audio flows,
        /// off the realtime thread.
        func prepare(
            for tap: MTAudioProcessingTap,
            units: [AVAudioUnit],
            format: AudioStreamBasicDescription,
            maximumFrames: Int
        ) {
            var description = format
            guard let renderFormat = AVAudioFormat(streamDescription: &description) else {
                Log.emit(.engine, .error, "audio processing could not read the stream format")
                return
            }
            release()

            do {
                try engine.enableManualRenderingMode(
                    .realtime,
                    format: renderFormat,
                    maximumFrameCount: AVAudioFrameCount(maximumFrames)
                )
                let accepted = engine.inputNode.setManualRenderingInputPCMFormat(renderFormat) { [weak self] _ in
                    guard let buffers = self?.sourceBuffer else {
                        return nil
                    }
                    return UnsafePointer(buffers.unsafeMutablePointer)
                }
                guard accepted else {
                    Log.emit(.engine, .error, "audio processing refused the stream format")
                    engine.disableManualRenderingMode()
                    return
                }
                connect(units, format: renderFormat)
                try engine.start()
                attachedUnits = units
                owner.store(identifier(of: tap), ordering: .releasing)
            } catch {
                Log.emit(.engine, .error, "audio processing could not start: \(error.localizedDescription)")
                disconnect()
                engine.disableManualRenderingMode()
            }
        }

        /// Renders one block in place. Realtime: no allocation, no locking, no awaiting.
        func process(for tap: MTAudioProcessingTap, buffers: UnsafeMutableAudioBufferListPointer, frames: Int) {
            guard owner.load(ordering: .acquiring) == identifier(of: tap) else {
                return
            }
            sourceBuffer = buffers

            var status: OSStatus = noErr
            _ = engine.manualRenderingBlock(AVAudioFrameCount(frames), buffers.unsafeMutablePointer, &status)
            sourceBuffer = nil
        }

        /// Tears the graph down, if `tap` still owns it. A tap that has already been superseded
        /// is ignored, which is what keeps a dying item from stopping the one that replaced it.
        func teardown(for tap: MTAudioProcessingTap) {
            let identifier = identifier(of: tap)
            guard owner.compareExchange(expected: identifier, desired: 0, ordering: .acquiringAndReleasing).exchanged else {
                return
            }
            release()
        }

        private func release() {
            owner.store(0, ordering: .releasing)
            engine.stop()
            disconnect()
            engine.disableManualRenderingMode()
        }

        /// Wires input through every unit in turn. The graph is only built here, because the
        /// format it has to be built at is whatever the tap hands us.
        private func connect(_ units: [AVAudioUnit], format: AVAudioFormat) {
            for unit in units {
                engine.attach(unit)
            }
            var source: AVAudioNode = engine.inputNode
            for unit in units {
                engine.connect(source, to: unit, format: format)
                source = unit
            }
            engine.connect(source, to: engine.mainMixerNode, format: format)
        }

        /// Detaching is what lets a caller keep one unit across items: a node may only belong to
        /// one engine at a time, so it has to leave this one before it can rejoin it.
        private func disconnect() {
            for unit in attachedUnits {
                engine.detach(unit)
            }
            attachedUnits = []
        }

        private func identifier(of tap: MTAudioProcessingTap) -> UInt {
            UInt(bitPattern: Unmanaged.passUnretained(tap).toOpaque())
        }
    }
#endif
