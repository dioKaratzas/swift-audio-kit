//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import XCTest
@testable import SwiftAudioKit

class AudioPlayer_SeekEvent_Tests: XCTestCase {
    var player: AudioPlayer!
    var listener: MockEventListener!

    override func setUp() {
        super.setUp()
        listener = MockEventListener()
        player = AudioPlayer()
    }

    override func tearDown() {
        listener = nil
        player = nil
        super.tearDown()
    }

    func testSeekForwardEventsAreGeneratedWhenASeekBegins() {
        let r = expectation(description: "Waiting for `onEvent` to get called")
        listener.eventClosure = { event, producer in
            XCTAssertEqual(event as? SeekEventProducer.SeekEvent, .seekForward)
            self.player.seekingBehavior.handleSeekingEnd(player: self.player, forward: true)
            r.fulfill()
        }

        player.seekEventProducer.eventListener = listener
        player.seekingBehavior = .changeTime(every: 1, delta: 30)
        player.seekingBehavior.handleSeekingStart(player: player, forward: true)

        waitForExpectations(timeout: 5) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }

    func testSeekBackwardEventsAreGeneratedWhenASeekBegins() {
        let r = expectation(description: "Waiting for `onEvent` to get called")
        listener.eventClosure = { event, producer in
            XCTAssertEqual(event as? SeekEventProducer.SeekEvent, .seekBackward)
            self.player.seekingBehavior.handleSeekingEnd(player: self.player, forward: false)
            r.fulfill()
        }

        player.seekEventProducer.eventListener = listener
        player.seekingBehavior = .changeTime(every: 1, delta: 30)
        player.seekingBehavior.handleSeekingStart(player: player, forward: false)

        waitForExpectations(timeout: 5) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }

    func testSeekEventsAreNotGeneratedWhenSeekChangesRate() {
        listener.eventClosure = { event, producer in
            XCTFail()
        }

        player.seekEventProducer.eventListener = listener
        player.seekingBehavior = .multiplyRate(2)
        player.seekingBehavior.handleSeekingStart(player: player, forward: false)

        let r = expectation(description: "Completing the expectation after 2 seconds to ensure no events are sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.player.seekingBehavior.handleSeekingEnd(player: self.player, forward: false)
            r.fulfill()
        }

        waitForExpectations(timeout: 5) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }

    func testRateMultiplierIsAppliedUponSeeking() {
        player.seekingBehavior = .multiplyRate(2)
        player.rate = 1

        player.seekingBehavior.handleSeekingStart(player: player, forward: false)
        XCTAssertEqual(player.rate, -2)
        player.seekingBehavior.handleSeekingEnd(player: player, forward: false)
        XCTAssertEqual(player.rate, 1)

        player.seekingBehavior.handleSeekingStart(player: player, forward: true)
        XCTAssertEqual(player.rate, 2)
        player.seekingBehavior.handleSeekingEnd(player: player, forward: true)
        XCTAssertEqual(player.rate, 1)
    }
}
