//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

#if canImport(UIKit)
    import UIKit

    public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
    import AppKit

    public typealias PlatformImage = NSImage
#endif

public enum Artwork: Sendable, Hashable {
    case data(Data)
    case url(URL)
}

#if canImport(UIKit)
    public extension Artwork {
        init?(image: PlatformImage) {
            guard let data = image.pngData() else {
                return nil
            }
            self = .data(data)
        }
    }

#elseif canImport(AppKit)
    public extension Artwork {
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
