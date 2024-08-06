//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import CoreMedia
import AVFoundation

extension AudioPlayer {
    /// Handles player events and updates the player's state accordingly.
    ///
    /// - Parameters:
    ///   - producer: The event producer that generated the player event.
    ///   - event: The player event to be handled.
    func handlePlayerEvent(from producer: EventProducer, with event: PlayerEventProducer.PlayerEvent) {
        switch event {
        case let .endedPlaying(error):
            handleEndedPlaying(with: error)

        case .interruptionBegan where state.isPlaying || state.isBuffering:
            handleInterruptionBegan()

        case let .interruptionEnded(shouldResume) where pausedForInterruption:
            handleInterruptionEnded(shouldResume: shouldResume)

        case let .loadedDuration(time):
            handleLoadedDuration(time)

        case let .loadedMetadata(metadata):
            handleLoadedMetadata(metadata)

        case .loadedMoreRange:
            handleLoadedMoreRange()

        case let .progressed(time):
            handleProgressed(time)

        case .readyToPlay:
            handleReadyToPlay()

        case let .routeChanged(deviceDisconnected):
            handleRouteChanged(deviceDisconnected)

        case .sessionMessedUp:
            handleSessionMessedUp()

        case .startedBuffering:
            handleStartedBuffering()

        default:
            break
        }
    }

    /// Handles the `endedPlaying` event.
    private func handleEndedPlaying(with error: Error?) {
        if let error {
            state = .failed(.foundationError(error))
        } else {
            nextOrStop()
        }
    }

    /// Handles the `interruptionBegan` event.
    private func handleInterruptionBegan() {
        backgroundHandler.beginBackgroundTask()
        pausedForInterruption = true
        pause()
    }

    /// Handles the `interruptionEnded` event.
    private func handleInterruptionEnded(shouldResume: Bool) {
        if resumeAfterInterruption, shouldResume {
            resume()
        }
        pausedForInterruption = false
        backgroundHandler.endBackgroundTask()
    }

    /// Handles the `loadedDuration` event.
    private func handleLoadedDuration(_ time: CMTime?) {
        guard let currentItem, let duration = time?.seconds else {
            return
        }
        if let metadata = currentItemDynamicMetadata() {
            nowPlayableService?.handleNowPlayablePlaybackChange(isPlaying: state.isPlaying, metadata: metadata)
        }
        delegate?.audioPlayer(self, didFindDuration: duration, for: currentItem)
    }

    /// Handles the `loadedMetadata` event.
    private func handleLoadedMetadata(_ metadata: [AVMetadataItem]) {
        guard let currentItem, !metadata.isEmpty else {
            return
        }
        currentItem.parseMetadata(metadata)
        delegate?.audioPlayer(self, didUpdateEmptyMetadataOn: currentItem, withData: metadata)

        if setNowPlayingMetadata {
            let isLiveStream = !currentItem.highestQualityURL.url.isOfflineURL
            let metadata = NowPlayableStaticMetadata(
                assetURL: currentItem.highestQualityURL.url,
                mediaType: .audio,
                isLiveStream: isLiveStream,
                title: currentItem.title,
                artist: currentItem.artist,
                artwork: currentItem.artwork,
                album: currentItem.album,
                trackCount: currentItem.trackCount,
                trackNumber: currentItem.trackNumber
            )
            nowPlayableService?.handleNowPlayableItemChange(metadata: metadata)
        }
    }

    /// Handles the `loadedMoreRange` event.
    private func handleLoadedMoreRange() {
        guard let currentItem, let loadedRange = currentItemLoadedRange else {
            return
        }
        delegate?.audioPlayer(self, didLoad: loadedRange, for: currentItem)

        if bufferingStrategy == .playWhenPreferredBufferDurationFull,
           state == .buffering,
           let loadedAhead = currentItemLoadedAhead,
           loadedAhead.isNormal,
           loadedAhead >= preferredBufferDurationBeforePlayback {
            playImmediately()
        }
    }

    /// Handles the `progressed` event.
    private func handleProgressed(_ time: CMTime?) {
        guard let progression = time?.seconds,
              let item = player?.currentItem, item.status == .readyToPlay else {
            return
        }

        if state.isBuffering || state.isPaused {
            handleBufferingOrPausedState()
        }

        // Notify delegate of progression update
        let duration = currentItemDuration ?? 0
        let percentage = duration > 0 ? (Float(progression / duration) * 100) : 0
        delegate?.audioPlayer(self, didUpdateProgressionTo: progression, percentageRead: percentage)
    }

    /// Handles the `readyToPlay` event.
    private func handleReadyToPlay() {
        if shouldResumePlaying {
            stateBeforeBuffering = nil
            state = .playing
            player?.rate = rate
            playImmediately()
        } else {
            player?.rate = 0
            state = .paused
        }

        retryEventProducer.stopProducingEvents()
        backgroundHandler.endBackgroundTask()
    }

    /// Handles the `routeChanged` event.
    private func handleRouteChanged(_ deviceDisconnected: Bool) {
        guard deviceDisconnected,
              let timebase = player?.currentItem?.timebase,
              CMTimebaseGetRate(timebase) == 0 else {
            return
        }
        state = .paused
    }

    /// Handles the `sessionMessedUp` event.
    private func handleSessionMessedUp() {
        #if os(iOS) || os(tvOS)
            setAudioSession(active: true)
            state = .stopped
            qualityAdjustmentEventProducer.interruptionCount += 1
            retryOrPlayNext()
        #endif
    }

    /// Handles the `startedBuffering` event.
    private func handleStartedBuffering() {
        if state == .playing && !qualityIsBeingChanged {
            qualityAdjustmentEventProducer.interruptionCount += 1
        }

        stateBeforeBuffering = state
        state = reachability.isReachable() || (currentItem?.soundURLs[currentQuality]?.isOfflineURL ?? false)
            ? .buffering
            : .waitingForConnection

        backgroundHandler.beginBackgroundTask()
    }

    /// Handles the state when buffering or paused during progression update.
    private func handleBufferingOrPausedState() {
        if shouldResumePlaying {
            stateBeforeBuffering = nil
            state = .playing
            player?.rate = rate
        } else {
            player?.rate = 0
            state = .paused
        }
        backgroundHandler.endBackgroundTask()
    }
}
