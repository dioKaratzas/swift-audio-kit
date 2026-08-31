//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

private enum Fixtures {
    static let item = AudioItem(url: URL(string: "https://example.com/anthem.mp3")!)

    static let everyState: [PlaybackState] = [
        .idle,
        .loading(item),
        .buffering(item),
        .playing(item),
        .paused(item, reason: .user),
        .waitingForConnection(item),
        .failed(item: item, error: .noPlayableItems)
    ]
}

@Suite("Playback state")
struct PlaybackStateTests {
    @Test("Every state but idle carries its item", arguments: Fixtures.everyState)
    func itemIsCarried(_ state: PlaybackState) {
        #expect(state.item == (state.isIdle ? nil : Fixtures.item))
    }

    @Test("Exactly one flag is true per state", arguments: Fixtures.everyState)
    func flagsAreExclusive(_ state: PlaybackState) {
        let flags = [
            state.isIdle, state.isLoading, state.isBuffering, state.isPlaying,
            state.isPaused, state.isWaitingForConnection, state.isFailed
        ]

        #expect(flags.filter(\.self).count == 1)
    }

    @Test(
        "The session stays active while an item is loaded",
        arguments: [
            (PlaybackState.idle, false),
            (.failed(item: Fixtures.item, error: .noPlayableItems), false),
            (.loading(Fixtures.item), true),
            (.buffering(Fixtures.item), true),
            (.playing(Fixtures.item), true),
            (.paused(Fixtures.item, reason: .user), true),
            (.waitingForConnection(Fixtures.item), true)
        ] as [(PlaybackState, Bool)]
    )
    func sessionActivity(_ state: PlaybackState, _ isActive: Bool) {
        #expect(state.isActive == isActive)
    }

    @Test(
        "Transient states are the ones worth a spinner",
        arguments: [
            (PlaybackState.loading(Fixtures.item), true),
            (.buffering(Fixtures.item), true),
            (.waitingForConnection(Fixtures.item), true),
            (.playing(Fixtures.item), false),
            (.paused(Fixtures.item, reason: .user), false),
            (.idle, false)
        ] as [(PlaybackState, Bool)]
    )
    func transience(_ state: PlaybackState, _ isTransient: Bool) {
        #expect(state.isTransient == isTransient)
    }

    @Test(
        "Transport availability follows the state",
        arguments: [
            (PlaybackState.idle, false, false),
            (.paused(Fixtures.item, reason: .user), true, false),
            (.playing(Fixtures.item), false, true),
            (.buffering(Fixtures.item), true, true)
        ] as [(PlaybackState, Bool, Bool)]
    )
    func transportAvailability(_ state: PlaybackState, _ canPlay: Bool, _ canPause: Bool) {
        #expect(state.canPlay == canPlay)
        #expect(state.canPause == canPause)
    }

    @Test("Errors and pause reasons are only read from their own case")
    func associatedValuesAreScoped() {
        #expect(PlaybackState.failed(item: Fixtures.item, error: .noPlayableItems).error == .noPlayableItems)
        #expect(PlaybackState.playing(Fixtures.item).error == nil)
        #expect(PlaybackState.paused(Fixtures.item, reason: .interruption).pauseReason == .interruption)
        #expect(PlaybackState.playing(Fixtures.item).pauseReason == nil)
    }
}
