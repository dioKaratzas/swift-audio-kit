//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public enum AudioQuality: Int, Sendable, Hashable, CaseIterable, Comparable {
    case low
    case medium
    case high

    public var lower: AudioQuality? {
        AudioQuality(rawValue: rawValue - 1)
    }

    public var higher: AudioQuality? {
        AudioQuality(rawValue: rawValue + 1)
    }

    public static func < (lhs: AudioQuality, rhs: AudioQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
