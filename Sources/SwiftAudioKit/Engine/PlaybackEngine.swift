//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if !os(watchOS)
    import AVFAudio
#endif

@MainActor
protocol PlaybackEngine: AnyObject {
    var signals: AsyncStream<EngineSignal> { get }
    var progress: PlaybackProgress { get }
    var timeControl: EngineTimeControl { get }
    var volume: Float { get set }
    var defaultRate: Float { get set }
    var playheadInterval: Duration { get set }
    var supportsAudioProcessing: Bool { get }

    func load(_ request: PlaybackRequest) async

    #if !os(watchOS)
        func setAudioUnits(_ units: [AVAudioUnit])
    #endif
    func unload()
    func play()
    func pause()

    @discardableResult
    func seek(to time: Duration, tolerance: SeekTolerance) async -> Bool
}
