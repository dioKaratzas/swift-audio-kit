//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

@MainActor
protocol PlaybackEngine: AnyObject {
    var signals: AsyncStream<EngineSignal> { get }
    var progress: PlaybackProgress { get }
    var timeControl: EngineTimeControl { get }
    var volume: Float { get set }
    var defaultRate: Float { get set }

    func load(_ request: PlaybackRequest) async
    func unload()
    func play()
    func pause()

    @discardableResult
    func seek(to time: Duration, tolerance: SeekTolerance) async -> Bool
}
