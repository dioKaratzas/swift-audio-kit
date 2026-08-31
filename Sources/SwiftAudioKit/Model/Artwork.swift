//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

#if canImport(UIKit)
    import UIKit

    /// Whichever image type the platform uses, so callers need no `#if` of their own.
    public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
    import AppKit

    /// Whichever image type the platform uses, so callers need no `#if` of their own.
    public typealias PlatformImage = NSImage
#endif

/// Cover art, as bytes already in hand or as somewhere to fetch them from.
public enum Artwork: Sendable, Hashable {
    /// Encoded image bytes, shown on the lock screen without any further work.
    case data(Data)

    /// Fetched in the background and cached per URL, so it reaches the lock screen an update
    /// later than `data` would.
    case url(URL)
}

#if canImport(UIKit)
    public extension Artwork {
        /// `nil` when the image has no PNG representation.
        init?(image: PlatformImage) {
            guard let data = image.pngData() else {
                return nil
            }
            self = .data(data)
        }
    }

#elseif canImport(AppKit)
    public extension Artwork {
        /// `nil` when the image has no PNG representation.
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
