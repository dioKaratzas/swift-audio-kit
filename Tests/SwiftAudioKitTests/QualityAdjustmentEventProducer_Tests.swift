//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import XCTest
@testable import SwiftAudioKit

class QualityAdjustmentEventProducer_Tests: XCTestCase {
    var listener: FakeEventListener!
    var producer: QualityAdjustmentEventProducer!

    override func setUp() {
        super.setUp()
        listener = FakeEventListener()
        producer = QualityAdjustmentEventProducer()
        producer.eventListener = listener
        producer.startProducingEvents()
    }

    override func tearDown() {
        listener = nil
        producer.stopProducingEvents()
        producer = nil
        super.tearDown()
    }

    func testEventListenerGetsCalledWhenInterruptionCountHitsLimit() {
        let e = expectation(description: "Waiting for `onEvent` to get called")
        listener.eventClosure = { event, producer in
            XCTAssertEqual(event as? QualityAdjustmentEventProducer.QualityAdjustmentEvent,
                QualityAdjustmentEventProducer.QualityAdjustmentEvent.goDown)
            e.fulfill()
        }

        producer.adjustQualityAfterInterruptionCount = 5
        producer.interruptionCount = producer.adjustQualityAfterInterruptionCount

        waitForExpectations(timeout: 1) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }

    func testInterruptionCountIsResetAfterHittingLimit() {
        producer.adjustQualityAfterInterruptionCount = 5
        producer.interruptionCount = producer.adjustQualityAfterInterruptionCount
        XCTAssertEqual(producer.interruptionCount, 0)
    }

    func testEventListenerDoesNotGetCalledWhenInterruptionCountIsIncrementedToLessThanLimits() {
        listener.eventClosure = { event, producer in
            XCTFail()
        }

        producer.adjustQualityAfterInterruptionCount = 5
        producer.interruptionCount = 1
        producer.interruptionCount = 2
        producer.interruptionCount = 3
        producer.interruptionCount = 4
    }

    func testEventListenerGetsCalledWhenInterruptionShouldGoUp() {
        let e = expectation(description: "Waiting for `onEvent` to get called")
        listener.eventClosure = { event, producer in
            XCTAssertEqual(event as? QualityAdjustmentEventProducer.QualityAdjustmentEvent,
                QualityAdjustmentEventProducer.QualityAdjustmentEvent.goUp)
            e.fulfill()
        }

        producer.adjustQualityTimeInterval = 1

        waitForExpectations(timeout: 1.5) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }

    func testEventListenerGetsCalledImmediatelyWhenAdjustQualityTimeIntervalIsChangedToAValueThatShouldAlreadyHaveBeenFired() {
        let e = expectation(description: "Waiting for `onEvent` to get called")
        listener.eventClosure = { event, producer in
            XCTAssertEqual(event as? QualityAdjustmentEventProducer.QualityAdjustmentEvent,
                QualityAdjustmentEventProducer.QualityAdjustmentEvent.goUp)
            e.fulfill()
        }

        producer.adjustQualityTimeInterval = 5
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
            self.producer.adjustQualityTimeInterval = 1
        }

        waitForExpectations(timeout: 2.5) { e in
            if let _ = e {
                XCTFail()
            }
        }
    }
}
