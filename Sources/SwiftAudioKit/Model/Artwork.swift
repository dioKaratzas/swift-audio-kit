//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

#if canImport(UIKit)
    import UIKit

    /// The image type the current platform uses, so callers need no `#if` of their own.
    ///
    /// `UIImage` on iOS, tvOS, watchOS, visionOS and Mac Catalyst; `NSImage` on macOS.
    public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
    import AppKit

    /// The image type the current platform uses, so callers need no `#if` of their own.
    ///
    /// `UIImage` on iOS, tvOS, watchOS, visionOS and Mac Catalyst; `NSImage` on macOS.
    public typealias PlatformImage = NSImage
#endif

/// Cover art for a track, as bytes already in hand or as somewhere to fetch them from.
///
/// Set artwork through ``AudioMetadata/artwork``, or let a ``MetadataParser`` discover it in
/// the stream. The player forwards whichever form you choose to the system's Now Playing
/// information, so the image reaches the lock screen and Control Center.
///
/// - Note: Artwork reaches the system only while
///   ``AudioPlayerConfiguration/publishesNowPlayingInfo`` is `true`, which is the default.
public enum Artwork: Sendable, Hashable {
    /// Encoded image bytes, shown on the lock screen without any further work.
    ///
    /// The bytes reach the system on the same update that carries the rest of the metadata,
    /// so the image and the title never appear a step apart.
    case data(Data)

    /// A location to fetch the image from, downloaded in the background and cached per URL.
    ///
    /// The image reaches the lock screen one update later than ``data(_:)`` would, because
    /// the fetch has to finish first. A fetch that fails is not retried.
    case url(URL)
}

#if canImport(UIKit)
    public extension Artwork {
        /// Creates artwork by encoding a platform image as PNG.
        ///
        /// - Parameter image: The image to encode. See ``PlatformImage``.
        /// - Returns: `nil` when the image has no PNG representation, such as one with no
        ///   underlying bitmap. Otherwise a ``data(_:)`` case holding the encoded bytes.
        init?(image: PlatformImage) {
            guard let data = image.pngData() else {
                return nil
            }
            self = .data(data)
        }
    }

#elseif canImport(AppKit)
    public extension Artwork {
        /// Creates artwork by encoding a platform image as PNG.
        ///
        /// - Parameter image: The image to encode. See ``PlatformImage``.
        /// - Returns: `nil` when the image has no PNG representation, such as one with no
        ///   underlying bitmap. Otherwise a ``data(_:)`` case holding the encoded bytes.
        init?(image: PlatformImage) {
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }
            self = .data(data)
        }
    }
#endif
