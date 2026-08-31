//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Engine time control")
struct EngineTimeControlTests {
    @Test(
        "A waiting indicator is shown only while stalls are being minimised",
        arguments: [
            (EngineTimeControl.playing, false),
            (.paused, false),
            (.waiting(reason: .evaluatingBufferingRate), false),
            (.waiting(reason: .noItemToPlay), false),
            (.waiting(reason: .minimizingStalls), true),
            (.waiting(reason: nil), true)
        ] as [(EngineTimeControl, Bool)]
    )
    func loadingIndicator(_ control: EngineTimeControl, _ shows: Bool) {
        #expect(control.showsLoadingIndicator == shows)
    }
}
