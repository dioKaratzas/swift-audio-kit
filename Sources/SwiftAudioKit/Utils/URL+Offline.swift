//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

extension URL {
    /// A boolean value indicating whether the resource can be accessed offline.
    ///
    /// This property checks whether a URL points to a resource that can be accessed without an internet connection.
    /// It returns `true` for file URLs, URLs with the "ipod-library" scheme, or URLs that point to a local server
    /// (i.e., with a host of "localhost" or "127.0.0.1").
    ///
    /// - Returns: `true` if the URL is considered accessible offline; otherwise, `false`.
    var isOfflineURL: Bool {
        isFileURL || scheme == "ipod-library" || host == "localhost" || host == "127.0.0.1"
    }
}
