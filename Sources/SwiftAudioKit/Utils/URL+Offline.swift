//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

extension URL {
    //swiftlint:disable variable_name
    /// A boolean value indicating whether a resource should be considered available when internet connection is down
    /// or not.
    var ap_isOfflineURL: Bool {
        return isFileURL || scheme == "ipod-library" || host == "localhost" || host == "127.0.0.1"
    }
}
