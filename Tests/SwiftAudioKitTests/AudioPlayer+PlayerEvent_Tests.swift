//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import XCTest
import AVFoundation
@testable import SwiftAudioKit

class AudioPlayer_PlayerEvent_Tests: XCTestCase {
    var player: MockAudioPlayer!
    var listener: MockEventListener!

    override func setUp() {
        super.setUp()
        listener = MockEventListener()
        player = MockAudioPlayer()
    }

    override func tearDown() {
        listener = nil
        player = nil
        super.tearDown()
    }

    func testProgressEventFiresDelegateCallWithTheRightInfo() {
        player.avPlayer.item = MockItem(url: URL(string: "https://github.com")!)
        player.avPlayer.item?.stat = .readyToPlay
        player.avPlayer.item?.dur = CMTime(timeInterval: 10)

        let e = expectation(description: "Waiting for `didUpdateProgression` to get called")
        let delegate = MockAudioPlayerDelegate()
        delegate.didUpdateProgression = { player, progression, percentage in
            XCTAssertEqual(player, self.player)
            XCTAssertEqual(progression, 2)
            XCTAssertEqual(percentage, 20)
            e.fulfill()
        }
        player.delegate = delegate

        player.handlePlayerEvent(from: player.playerEventProducer, with: .progressed(time: CMTime(timeInterval: 2)))
        waitForExpectations(timeout: 1) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }

    func testProgressEventFiresDelegateCallWithZeroPercentageWhenDurationIsUnknown() {
        player.avPlayer.item = MockItem(url: URL(string: "https://github.com")!)
        player.avPlayer.item?.stat = .readyToPlay
        player.avPlayer.item?.dur = CMTime(value: 0, timescale: 1, flags: [], epoch: 0)//This is an invalid time

        let e = expectation(description: "Waiting for `didUpdateProgression` to get called")
        let delegate = MockAudioPlayerDelegate()
        delegate.didUpdateProgression = { player, progression, percentage in
            XCTAssertEqual(player, self.player)
            XCTAssertEqual(progression, 2)
            XCTAssertEqual(percentage, 0)
            e.fulfill()
        }
        player.delegate = delegate

        player.handlePlayerEvent(from: player.playerEventProducer, with: .progressed(time: CMTime(timeInterval: 2)))
        waitForExpectations(timeout: 1) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }
}
