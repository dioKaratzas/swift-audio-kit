//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// Represents the mode in which the player should play. Modes can be combined so that you can play in `.shuffle`
/// mode and still `.repeatAll`.
public struct AudioPlayerMode: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// In this mode, the player's queue will be played as given.
    public static let normal = AudioPlayerMode([])

    /// In this mode, the player's queue is shuffled randomly.
    public static let shuffle = AudioPlayerMode(rawValue: 1 << 0)

    /// In this mode, the player will continuously play the same item over and over.
    public static let `repeat` = AudioPlayerMode(rawValue: 1 << 1)

    /// In this mode, the player will continuously play the same queue over and over.
    public static let repeatAll = AudioPlayerMode(rawValue: 1 << 2)
}
