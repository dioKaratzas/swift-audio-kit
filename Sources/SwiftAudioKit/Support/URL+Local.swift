//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

extension URL {
    var isLocal: Bool {
        isFileURL || scheme == "ipod-library" || host == "localhost" || host == "127.0.0.1"
    }
}
