//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

/// A sendable projection of one timed metadata item, taken where it leaves AVFoundation.
///
/// `AVMetadataItem` is a reference type that is not `Sendable`, so the player reads the values
/// it cares about at the boundary and hands them on as this. A ``MetadataParser`` receives an
/// array of these — one burst — and turns them into ``AudioMetadata``.
public struct MetadataEntry: Sendable, Hashable {
    /// The format-independent key, set only for the fields AVFoundation normalises.
    ///
    /// Compare against the raw values of `AVMetadataKey`, such as
    /// `AVMetadataKey.commonKeyTitle.rawValue`. `nil` for everything else, which is most of
    /// what a live stream sends.
    public var commonKey: String?

    /// The format-specific key, which is all a Shoutcast or ID3 field ever carries.
    ///
    /// Compare against the raw values of `AVMetadataIdentifier`, or against a station's own
    /// string such as `"icy/StreamTitle"`.
    public var identifier: String?

    /// The value read as text.
    ///
    /// Where most fields arrive, including the numeric ones: ID3 writes a track number as text
    /// in either `number` or `number/total` form.
    public var stringValue: String?

    /// The value read as a number.
    ///
    /// Set only where the format is genuinely numeric, so check ``stringValue`` as well before
    /// concluding a numeric field is absent.
    public var numberValue: Double?

    /// The value read as bytes, which is how embedded cover art arrives.
    ///
    /// Wrap it in ``Artwork/data(_:)`` to use it.
    public var dataValue: Data?

    /// Creates an entry from the fields you have.
    ///
    /// Provided mainly so a ``MetadataParser`` can be exercised in tests without a live stream.
    ///
    /// - Parameters:
    ///   - commonKey: The normalised key, or `nil`. Defaults to `nil`.
    ///   - identifier: The format-specific key, or `nil`. Defaults to `nil`.
    ///   - stringValue: The value as text, or `nil`. Defaults to `nil`.
    ///   - numberValue: The value as a number, or `nil`. Defaults to `nil`.
    ///   - dataValue: The value as bytes, or `nil`. Defaults to `nil`.
    ///
    /// - Note: Every argument defaults to `nil` because one entry carries at most a couple of
    ///   them: a key and one representation of its value.
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
