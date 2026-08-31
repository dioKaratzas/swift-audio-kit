//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

@Suite("Playback state")
struct PlaybackStateTests {
    private let item = AudioItem(url: URL(string: "https://example.com/anthem.mp3")!)

    private var everyState: [PlaybackState] {
        [
            .idle,
            .loading(item),
            .buffering(item),
            .playing(item),
            .paused(item, reason: .user),
            .waitingForConnection(item),
            .failed(item: item, error: .noPlayableItems)
        ]
    }

    @Test
    func `Every state but idle carries its item`() {
        for state in everyState where !state.isIdle {
            #expect(state.item == item)
        }
        #expect(PlaybackState.idle.item == nil)
    }

    @Test
    func `Exactly one flag is true per state`() {
        for state in everyState {
            let flags = [
                state.isIdle, state.isLoading, state.isBuffering, state.isPlaying,
                state.isPaused, state.isWaitingForConnection, state.isFailed
            ]
            #expect(flags.filter(\.self).count == 1)
        }
    }

    @Test
    func `The session stays active while an item is loaded`() {
        #expect(!PlaybackState.idle.isActive)
        #expect(!PlaybackState.failed(item: item, error: .noPlayableItems).isActive)
        #expect(PlaybackState.loading(item).isActive)
        #expect(PlaybackState.playing(item).isActive)
        #expect(PlaybackState.paused(item, reason: .user).isActive)
    }

    @Test
    func `Transient states are the ones worth a spinner`() {
        #expect(PlaybackState.loading(item).isTransient)
        #expect(PlaybackState.buffering(item).isTransient)
        #expect(PlaybackState.waitingForConnection(item).isTransient)
        #expect(!PlaybackState.playing(item).isTransient)
        #expect(!PlaybackState.paused(item, reason: .user).isTransient)
    }

    @Test
    func `Transport availability follows the state`() {
        #expect(!PlaybackState.idle.canPlay)
        #expect(!PlaybackState.idle.canPause)
        #expect(PlaybackState.paused(item, reason: .user).canPlay)
        #expect(!PlaybackState.playing(item).canPlay)
        #expect(PlaybackState.playing(item).canPause)
    }

    @Test
    func `Errors and pause reasons are only read from their own case`() {
        #expect(PlaybackState.failed(item: item, error: .noPlayableItems).error == .noPlayableItems)
        #expect(PlaybackState.playing(item).error == nil)
        #expect(PlaybackState.paused(item, reason: .interruption).pauseReason == .interruption)
        #expect(PlaybackState.playing(item).pauseReason == nil)
    }

    @Test
    func `Only a listener-requested pause is manual`() {
        #expect(!PauseReason.user.isAutomatic)
        for reason in PauseReason.allCases where reason != .user {
            #expect(reason.isAutomatic)
        }
    }
}
