//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public enum RepeatMode: Sendable, Hashable, CaseIterable {
    case off
    case one
    case all

    public var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

public struct PlaybackMode: Sendable, Hashable {
    public var repeatMode: RepeatMode
    public var isShuffled: Bool

    public init(repeatMode: RepeatMode = .off, isShuffled: Bool = false) {
        self.repeatMode = repeatMode
        self.isShuffled = isShuffled
    }

    public static let normal = PlaybackMode()
    public static let shuffle = PlaybackMode(isShuffled: true)
    public static let repeatOne = PlaybackMode(repeatMode: .one)
    public static let repeatAll = PlaybackMode(repeatMode: .all)
}
