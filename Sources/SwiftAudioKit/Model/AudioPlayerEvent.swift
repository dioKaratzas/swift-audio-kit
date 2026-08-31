//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public enum AudioPlayerEvent: Sendable, Hashable {
    case stateChanged(from: PlaybackState, to: PlaybackState)
    case itemChanged(from: AudioItem?, to: AudioItem?)
    case itemFinished(AudioItem)
    case queueExhausted
    case durationResolved(Duration, for: AudioItem.ID)
    case metadataUpdated(AudioMetadata, for: AudioItem.ID)
    case qualityChanged(from: AudioQuality, to: AudioQuality)
    case networkChanged(NetworkStatus)
    case interrupted(PauseReason)
    case interruptionEnded(shouldResume: Bool)
    case recoverableErrorLogged(PlaybackFailure)
    case failed(AudioPlayerError)
}
