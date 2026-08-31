//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// A sendable, comparable snapshot of an error, taken where the error leaves AVFoundation.
///
/// AVFoundation and `AVAudioSession` report failures as `NSError`, which is neither
/// `Sendable` nor usefully `Hashable`. The player flattens each one into this value at the
/// boundary, so a failure can cross isolation domains, be stored, and be compared.
public struct PlaybackFailure: Error, Sendable, Hashable {
    /// The originating `NSError` domain, kept verbatim so it can be matched against.
    ///
    /// Typically `AVFoundationErrorDomain`, `NSURLErrorDomain` or `NSOSStatusErrorDomain`.
    public let domain: String

    /// The originating `NSError` code, unique only within its ``domain``.
    ///
    /// Always test it together with the domain; the same integer means different things in
    /// different domains.
    public let code: Int

    /// Localised prose describing the failure, taken from the original error.
    ///
    /// - Important: Deliberately excluded from equality and hashing, because the wording is
    ///   localised and can change between OS releases. Show it; never branch on it.
    public let message: String

    /// Creates a failure from its parts.
    ///
    /// Use this in tests, and to report an error that did not originate in AVFoundation.
    ///
    /// - Parameters:
    ///   - domain: The error domain to record. Follow reverse-DNS convention for your own
    ///     domains so they cannot collide with Apple's.
    ///   - code: The error code within that domain.
    ///   - message: Localised prose for a listener. Not part of equality.
    public init(domain: String, code: Int, message: String) {
        self.domain = domain
        self.code = code
        self.message = message
    }

    /// Creates a failure by flattening any error through `NSError`.
    ///
    /// Every Swift error bridges to `NSError`, so this never fails: ``domain`` and ``code``
    /// come from the bridged value and ``message`` from its `localizedDescription`.
    ///
    /// - Parameter error: The error to capture. A Swift `enum` error that does not conform to
    ///   `CustomNSError` bridges to a synthesised domain naming the type, which is stable
    ///   within a build but not something to hard-code against.
    public init(_ error: any Error) {
        let nsError = error as NSError
        domain = nsError.domain
        code = nsError.code
        message = nsError.localizedDescription
    }

    /// Returns a Boolean value indicating whether two failures describe the same error.
    ///
    /// Compares ``domain`` and ``code`` only. ``message`` is excluded because it is
    /// localised, so the same failure in two languages compares equal.
    ///
    /// - Parameters:
    ///   - lhs: A failure to compare.
    ///   - rhs: Another failure to compare against.
    /// - Returns: `true` when both the domain and the code match.
    public static func == (lhs: PlaybackFailure, rhs: PlaybackFailure) -> Bool {
        lhs.domain == rhs.domain && lhs.code == rhs.code
    }

    /// Hashes the essential components of this value.
    ///
    /// Feeds ``domain`` and ``code`` into the hasher and omits ``message``, to stay
    /// consistent with equality.
    ///
    /// - Parameter hasher: The hasher to use when combining the components of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(domain)
        hasher.combine(code)
    }
}

extension PlaybackFailure: CustomStringConvertible {
    /// A description naming the domain and code alongside the message.
    ///
    /// Written for logs and bug reports, where the domain and code the message alone would
    /// hide are the parts worth having. Use ``message`` for anything a listener will read.
    public var description: String {
        "\(domain) \(code): \(message)"
    }
}
