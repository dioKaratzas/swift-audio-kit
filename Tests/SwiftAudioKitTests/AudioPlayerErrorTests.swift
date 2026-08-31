//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

@Suite("Player errors")
struct AudioPlayerErrorTests {
    @Test
    func `A captured error keeps its domain, code and message`() {
        let underlying = NSError(domain: URLError.errorDomain, code: -1001, userInfo: [
            NSLocalizedDescriptionKey: "The request timed out."
        ])

        let failure = PlaybackFailure(underlying)

        #expect(failure.domain == URLError.errorDomain)
        #expect(failure.code == -1001)
        #expect(failure.message == "The request timed out.")
    }

    @Test
    func `Failures match on domain and code, not on the localised message`() {
        let english = PlaybackFailure(domain: "Test", code: 7, message: "Timed out")
        let greek = PlaybackFailure(domain: "Test", code: 7, message: "Έληξε το χρονικό όριο")
        let other = PlaybackFailure(domain: "Test", code: 8, message: "Timed out")

        #expect(english == greek)
        #expect(english != other)
        #expect(english.hashValue == greek.hashValue)
    }

    @Test
    func `Only transient errors invite a retry`() {
        let failure = PlaybackFailure(domain: "Test", code: 1, message: "Boom")

        #expect(AudioPlayerError.playbackFailed(failure).isRetryable)
        #expect(AudioPlayerError.connectionLost(after: .seconds(60)).isRetryable)
        #expect(AudioPlayerError.audioSessionFailed(failure).isRetryable)
        #expect(!AudioPlayerError.retryLimitReached(attempts: 3).isRetryable)
        #expect(!AudioPlayerError.noPlayableItems.isRetryable)
        #expect(!AudioPlayerError.itemUnavailable(AudioItem.ID()).isRetryable)
    }

    @Test
    func `The underlying failure is exposed only where one exists`() {
        let failure = PlaybackFailure(domain: "Test", code: 1, message: "Boom")

        #expect(AudioPlayerError.playbackFailed(failure).failure == failure)
        #expect(AudioPlayerError.audioSessionFailed(failure).failure == failure)
        #expect(AudioPlayerError.noPlayableItems.failure == nil)
    }

    @Test
    func `Every error describes itself`() {
        let failure = PlaybackFailure(domain: "Test", code: 1, message: "Boom")
        let errors: [AudioPlayerError] = [
            .retryLimitReached(attempts: 3),
            .playbackFailed(failure),
            .connectionLost(after: .seconds(60)),
            .itemUnavailable(AudioItem.ID()),
            .noPlayableItems,
            .audioSessionFailed(failure)
        ]

        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}
