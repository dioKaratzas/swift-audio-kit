//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// A sendable, comparable snapshot of an error, taken where the error crosses out of AVFoundation.
public struct PlaybackFailure: Error, Sendable, Hashable {
    /// The originating `NSError` domain, kept verbatim so it can be matched against.
    public let domain: String

    /// The originating `NSError` code, unique only within its domain.
    public let code: Int

    /// Localised prose for a listener, which is deliberately excluded from equality.
    public let message: String

    /// Builds a failure by hand, for tests and for errors raised outside AVFoundation.
    public init(domain: String, code: Int, message: String) {
        self.domain = domain
        self.code = code
        self.message = message
    }

    /// Flattens any error through `NSError`, which every Swift error bridges to.
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

    /// Hashes domain and code only, to stay consistent with equality.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(domain)
        hasher.combine(code)
    }
}

extension PlaybackFailure: CustomStringConvertible {
    /// For logs and bug reports: names the domain and code the message alone would hide.
    public var description: String {
        "\(domain) \(code): \(message)"
    }
}
