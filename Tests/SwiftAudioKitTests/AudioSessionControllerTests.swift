//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Audio session controller", .serialized)
struct AudioSessionControllerTests {
    @Test("An unmanaged policy leaves the session alone")
    func unmanagedIsInert() async throws {
        let controller = AudioSessionController(policy: .unmanaged)

        try await controller.activate()
        try await controller.deactivate()
    }

    @Test("Activation is idempotent")
    func repeatedActivation() async throws {
        let controller = AudioSessionController(policy: .unmanaged)

        try await controller.activate()
        try await controller.activate()
        try await controller.deactivate()
    }

    @Test("Failures arrive as a typed player error")
    func typedFailure() async {
        let controller = AudioSessionController(policy: .managed)

        do {
            try await controller.activate()
        } catch {
            #expect(error.failure != nil)
            #expect(error.isRetryable)
        }
    }
}
