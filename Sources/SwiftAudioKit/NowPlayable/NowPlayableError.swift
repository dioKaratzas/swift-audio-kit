/*
 See the LICENSE.txt file for this sample’s licensing information.

 Abstract:
 `NowPlayableError` declares errors specific to the NowPlayable protocol.
 */

import Foundation

public enum NowPlayableError: LocalizedError {
    case noRegisteredCommands
    case cannotSetCategory(Error)
    case cannotActivateSession(Error)
    case cannotReactivateSession(Error)

    public var errorDescription: String? {
        switch self {
        case .noRegisteredCommands:
            "At least one remote command must be registered."

        case let .cannotSetCategory(error):
            "The audio session category could not be set:\n\(error)"

        case let .cannotActivateSession(error):
            "The audio session could not be activated:\n\(error)"

        case let .cannotReactivateSession(error):
            "The audio session could not be resumed after interruption:\n\(error)"
        }
    }
}
