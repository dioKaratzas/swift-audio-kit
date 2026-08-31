//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

private enum Fixtures {
    static let failure = PlaybackFailure(domain: "Test", code: 1, message: "Boom")
}

@Suite("Player errors")
struct AudioPlayerErrorTests {
    @Test("A captured error keeps its domain, code and message")
    func capturingAnError() {
        let underlying = NSError(domain: URLError.errorDomain, code: -1001, userInfo: [
            NSLocalizedDescriptionKey: "The request timed out."
        ])

        let failure = PlaybackFailure(underlying)

        #expect(failure.domain == URLError.errorDomain)
        #expect(failure.code == -1001)
        #expect(failure.message == "The request timed out.")
    }

    @Test("Failures match on domain and code, not on the localised message")
    func failureEquality() {
        let english = PlaybackFailure(domain: "Test", code: 7, message: "Timed out")
        let greek = PlaybackFailure(domain: "Test", code: 7, message: "Έληξε το χρονικό όριο")
        let other = PlaybackFailure(domain: "Test", code: 8, message: "Timed out")

        #expect(english == greek)
        #expect(english != other)
        #expect(english.hashValue == greek.hashValue)
    }

    @Test(
        "Only transient errors invite a retry",
        arguments: [
            (AudioPlayerError.playbackFailed(Fixtures.failure), true),
            (.connectionLost(after: .seconds(60)), true),
            (.audioSessionFailed(Fixtures.failure), true),
            (.retryLimitReached(attempts: 3), false),
            (.noPlayableItems, false),
            (.itemUnavailable(UUID()), false)
        ] as [(AudioPlayerError, Bool)]
    )
    func retryability(_ error: AudioPlayerError, _ isRetryable: Bool) {
        #expect(error.isRetryable == isRetryable)
    }

    @Test(
        "The underlying failure is exposed only where one exists",
        arguments: [
            (AudioPlayerError.playbackFailed(Fixtures.failure), Fixtures.failure),
            (.audioSessionFailed(Fixtures.failure), Fixtures.failure),
            (.noPlayableItems, nil),
            (.retryLimitReached(attempts: 3), nil)
        ] as [(AudioPlayerError, PlaybackFailure?)]
    )
    func underlyingFailure(_ error: AudioPlayerError, _ expected: PlaybackFailure?) {
        #expect(error.failure == expected)
    }
}
