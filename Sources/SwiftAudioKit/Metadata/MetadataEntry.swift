//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// A sendable projection of one timed metadata item, taken where it leaves AVFoundation.
public struct MetadataEntry: Sendable, Hashable {
    /// The format-independent key, set only for the handful of fields AVFoundation normalises.
    public var commonKey: String?

    /// The format-specific key, which is all a Shoutcast or ID3 field ever carries.
    public var identifier: String?

    /// The value read as text, which is where ID3 puts even its numeric fields.
    public var stringValue: String?

    /// The value read as a number, set only where the format is genuinely numeric.
    public var numberValue: Double?

    /// The value read as bytes, which is how embedded cover art arrives.
    public var dataValue: Data?

    /// Every field defaults to `nil`, since one entry carries at most a couple of them.
    public init(
        commonKey: String? = nil,
        identifier: String? = nil,
        stringValue: String? = nil,
        numberValue: Double? = nil,
        dataValue: Data? = nil
    ) {
        self.commonKey = commonKey
        self.identifier = identifier
        self.stringValue = stringValue
        self.numberValue = numberValue
        self.dataValue = dataValue
    }
}
