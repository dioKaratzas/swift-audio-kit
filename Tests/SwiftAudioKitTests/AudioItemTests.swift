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
    @Test(
        "The display title prefers metadata over the file name",
        arguments: [
            (AudioMetadata(), "anthem"),
            (AudioMetadata(title: "Anthem"), "Anthem"),
        ]
    )
    func displayTitle(_ metadata: AudioMetadata, _ expected: String) throws {
        let url = try #require(URL(string: "https://example.com/anthem.mp3"))

        #expect(AudioItem(url: url, metadata: metadata).displayTitle == expected)
    }
}
