//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
@testable import SwiftAudioKit

@Suite("Network status")
struct NetworkStatusTests {
    @Test(
        "Only a positive report of no route blocks playback",
        arguments: [
            (NetworkStatus.Reachability.available, true),
            (.unknown, true),
            (.unavailable, false)
        ] as [(NetworkStatus.Reachability, Bool)]
    )
    func usability(_ reachability: NetworkStatus.Reachability, _ isUsable: Bool) {
        #expect(NetworkStatus(reachability: reachability).isUsable == isUsable)
    }

    @Test(
        "Metered and restricted links both ask for less data",
        arguments: [
            (false, false, false),
            (true, false, true),
            (false, true, true),
            (true, true, true)
        ]
    )
    func reducedData(_ isExpensive: Bool, _ isConstrained: Bool, _ prefersReduced: Bool) {
        let status = NetworkStatus(
            reachability: .available,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )

        #expect(status.prefersReducedData == prefersReduced)
    }
}
