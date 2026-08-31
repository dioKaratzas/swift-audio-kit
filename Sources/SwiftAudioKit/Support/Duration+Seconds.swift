//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

extension Duration {
    var totalSeconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }

    init(totalSeconds: Double) {
        self = .seconds(totalSeconds)
    }
}
