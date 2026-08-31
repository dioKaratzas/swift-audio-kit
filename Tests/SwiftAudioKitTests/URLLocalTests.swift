//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

@Suite("URL locality")
struct URLLocalTests {
    @Test(
        arguments: [
            "file:///Users/someone/track.mp3",
            "ipod-library://item/item.m4a?id=1",
            "http://localhost:8080/track.mp3",
            "http://127.0.0.1:8080/track.mp3"
        ]
    )
    func `Locally reachable URLs`(_ string: String) throws {
        #expect(try #require(URL(string: string)).isLocal)
    }

    @Test(
        arguments: [
            "https://example.com/track.mp3",
            "https://example.com/stream.m3u8",
            "http://192.168.1.10/track.mp3"
        ]
    )
    func `Remote URLs`(_ string: String) throws {
        #expect(try !#require(URL(string: string)).isLocal)
    }
}
