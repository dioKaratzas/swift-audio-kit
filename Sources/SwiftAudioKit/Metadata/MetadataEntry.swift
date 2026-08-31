//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// A sendable projection of one timed metadata item, taken where it leaves AVFoundation.
public struct MetadataEntry: Sendable, Hashable {
    public var commonKey: String?
    public var identifier: String?
    public var stringValue: String?
    public var numberValue: Double?
    public var dataValue: Data?

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
