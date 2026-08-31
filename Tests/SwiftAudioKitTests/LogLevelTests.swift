//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Log level", .serialized)
struct LogLevelTests {
    @Test("Levels order from most to least verbose")
    func ordering() {
        #expect(AudioPlayerLog.Level.debug < .info)
        #expect(AudioPlayerLog.Level.info < .notice)
        #expect(AudioPlayerLog.Level.notice < .error)
        #expect(AudioPlayerLog.Level.error < .off)
    }

    @Test("The level round-trips through its storage")
    func storage() {
        let original = AudioPlayerLog.level
        defer { AudioPlayerLog.level = original }

        for level in AudioPlayerLog.Level.allCases {
            AudioPlayerLog.level = level
            #expect(AudioPlayerLog.level == level)
        }
    }

    @Test("Messages below the level are never built")
    func suppressedMessagesAreNotBuilt() {
        let original = AudioPlayerLog.level
        defer { AudioPlayerLog.level = original }
        AudioPlayerLog.level = .error

        var built = 0
        Log.emit(.player, .debug, { built += 1; return "debug" }())
        Log.emit(.player, .notice, { built += 1; return "notice" }())
        #expect(built == 0)

        Log.emit(.player, .error, { built += 1; return "error" }())
        #expect(built == 1)
    }

    @Test("Turning logging off suppresses every level")
    func offSuppressesEverything() {
        let original = AudioPlayerLog.level
        defer { AudioPlayerLog.level = original }
        AudioPlayerLog.level = .off

        var built = 0
        for level in AudioPlayerLog.Level.allCases {
            Log.emit(.player, level, { built += 1; return "message" }())
        }

        #expect(built == 0)
    }
}
