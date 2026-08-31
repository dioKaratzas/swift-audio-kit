//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import AVFoundation
@testable import SwiftAudioKit

@Suite("Metadata parsing")
struct MetadataParserTests {
    private let parser = DefaultMetadataParser()

    private func common(_ key: AVMetadataKey, _ value: String) -> MetadataEntry {
        MetadataEntry(commonKey: key.rawValue, stringValue: value)
    }

    @Test("Common keys map onto the metadata fields")
    func commonKeys() {
        let metadata = parser.metadata(from: [
            common(.commonKeyTitle, "Anthem"),
            common(.commonKeyArtist, "Someone"),
            common(.commonKeyAlbumName, "Debut")
        ])

        #expect(metadata.title == "Anthem")
        #expect(metadata.artist == "Someone")
        #expect(metadata.album == "Debut")
    }

    @Test("Artwork arrives as data")
    func artwork() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let entry = MetadataEntry(commonKey: AVMetadataKey.commonKeyArtwork.rawValue, dataValue: data)

        #expect(parser.metadata(from: [entry]).artwork == .data(data))
    }

    @Test("Entries carrying nothing useful are ignored")
    func unknownEntries() {
        let metadata = parser.metadata(from: [
            MetadataEntry(commonKey: "somethingElse", stringValue: "value"),
            MetadataEntry(identifier: "unknown", stringValue: "value")
        ])

        #expect(metadata.isEmpty)
    }

    @Test(
        "ID3 track numbers come as a bare number or number over total",
        arguments: [
            ("3", 3, nil),
            ("3/12", 3, 12),
            ("", nil, nil)
        ] as [(String, Int?, Int?)]
    )
    func trackNumbers(_ raw: String, _ number: Int?, _ count: Int?) {
        let entry = MetadataEntry(
            identifier: AVMetadataIdentifier.id3MetadataTrackNumber.rawValue,
            stringValue: raw
        )

        let metadata = parser.metadata(from: [entry])

        #expect(metadata.trackNumber == number)
        #expect(metadata.trackCount == count)
    }

    @Test("A numeric track value is preferred over parsing the string")
    func numericTrackNumber() {
        let entry = MetadataEntry(
            identifier: AVMetadataIdentifier.id3MetadataTrackNumber.rawValue,
            numberValue: 7
        )

        #expect(parser.metadata(from: [entry]).trackNumber == 7)
    }

    @Test("A common key outranks the ID3 identifier for the same field")
    func commonKeyWins() {
        let metadata = parser.metadata(from: [
            common(.commonKeyTitle, "Common title"),
            MetadataEntry(
                identifier: AVMetadataIdentifier.id3MetadataTitleDescription.rawValue,
                stringValue: "ID3 title"
            )
        ])

        #expect(metadata.title == "Common title")
    }
}
