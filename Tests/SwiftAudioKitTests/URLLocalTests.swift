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
        "Locally reachable URLs",
        arguments: [
            "file:///Users/someone/track.mp3",
            "ipod-library://item/item.m4a?id=1",
            "http://localhost:8080/track.mp3",
            "http://127.0.0.1:8080/track.mp3"
        ]
    )
    func localURLs(_ string: String) throws {
        let url = try #require(URL(string: string))

        #expect(url.isLocal)
    }

    @Test(
        "Remote URLs",
        arguments: [
            "https://example.com/track.mp3",
            "https://example.com/stream.m3u8",
            "http://192.168.1.10/track.mp3"
        ]
    )
    func remoteURLs(_ string: String) throws {
        let url = try #require(URL(string: string))

        #expect(!url.isLocal)
    }

    @Test(
        "HLS playlists are recognised by extension",
        arguments: [
            ("https://example.com/stream.m3u8", true),
            ("https://example.com/stream.M3U8", true),
            ("https://example.com/track.mp3", false)
        ]
    )
    func hlsDetection(_ string: String, _ isPlaylist: Bool) throws {
        let url = try #require(URL(string: string))

        #expect(url.isHLSPlaylist == isPlaylist)
    }
}
