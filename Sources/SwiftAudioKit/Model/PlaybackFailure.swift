//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// A sendable, comparable snapshot of an error, taken where the error crosses out of AVFoundation.
public struct PlaybackFailure: Error, Sendable, Hashable {
    public let domain: String
    public let code: Int
    public let message: String

    public init(domain: String, code: Int, message: String) {
        self.domain = domain
        self.code = code
        self.message = message
    }

    public init(_ error: any Error) {
        let nsError = error as NSError
        domain = nsError.domain
        code = nsError.code
        message = nsError.localizedDescription
    }

    /// Two failures match on domain and code alone, because messages are localised.
    public static func == (lhs: PlaybackFailure, rhs: PlaybackFailure) -> Bool {
        lhs.domain == rhs.domain && lhs.code == rhs.code
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(domain)
        hasher.combine(code)
    }
}

extension PlaybackFailure: CustomStringConvertible {
    public var description: String {
        "\(domain) \(code): \(message)"
    }
}
