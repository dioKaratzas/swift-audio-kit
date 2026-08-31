//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

enum Signal: Sendable, Hashable {
    case play
    case pause
    case stop
    case playItems([AudioItem], startingAt: Int)
    case append([AudioItem])
    case insertNext(AudioItem)
    case remove(AudioItem.ID)
    case move(from: Int, to: Int)
    case removeAll
    case jump(AudioItem.ID)
    case next
    case previous
    case setQuality(AudioQuality)
    case setMode(PlaybackMode)
    case setSkipped(Set<AudioItem.ID>)

    case engine(EngineSignal)
    case network(NetworkStatus)

    case sessionFailed(AudioPlayerError)
    case interrupted(PauseReason)
    case interruptionEnded(shouldResume: Bool)

    case retryDue(generation: Int)
    case connectionLossDeadlineReached(generation: Int)
    case qualityUpgradeDue
}

enum Effect: Sendable, Hashable {
    case load(PlaybackRequest, generation: Int)
    case unload
    case play
    case pause
    case seek(to: Duration, generation: Int)

    case activateSession
    case deactivateSession
    case beginBackgroundActivity
    case endBackgroundActivity

    case scheduleRetry(after: Duration, generation: Int)
    case cancelRetry
    case startConnectionLossTimer(deadline: Duration, generation: Int)
    case cancelConnectionLossTimer
    case scheduleQualityUpgrade(after: Duration)

    case emit(AudioPlayerEvent)
}
