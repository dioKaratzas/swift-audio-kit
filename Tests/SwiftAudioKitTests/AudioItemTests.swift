//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

@Suite("Audio item")
struct AudioItemTests {
    private let url = URL(string: "https://example.com/anthem.mp3")!

    @Test
    func `Identifiers are unique per item`() {
        #expect(AudioItem(url: url).id != AudioItem(url: url).id)
    }

    @Test
    func `Items sharing an identifier and payload are equal`() {
        let id = AudioItem.ID()

        #expect(AudioItem(id: id, url: url) == AudioItem(id: id, url: url))
    }

    @Test
    func `The display title prefers metadata over the file name`() {
        #expect(AudioItem(url: url).displayTitle == "anthem")
        #expect(AudioItem(url: url, metadata: AudioMetadata(title: "Anthem")).displayTitle == "Anthem")
    }

    @Test
    func `Locality is delegated to the sources`() {
        #expect(AudioItem(url: URL(fileURLWithPath: "/tmp/anthem.mp3")).isLocal)
        #expect(!AudioItem(url: url).isLocal)
    }
}
