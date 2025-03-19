//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import XCTest
@testable import SwiftAudioKit

class BackgroundHandler_Tests: XCTestCase {
    var application = MockApplication()
    var backgroundHandler: BackgroundHandler!

    override func setUp() {
        super.setUp()
        backgroundHandler = BackgroundHandler()
        backgroundHandler.backgroundTaskCreator = application
    }

    override func tearDown() {
        backgroundHandler = nil
        super.tearDown()
    }

    func testMultipleBeginDoesNotChangeIdentifier() {
        application.onBegin = { handler in
            UIBackgroundTaskIdentifier(rawValue: 1)
        }
        XCTAssert(backgroundHandler.beginBackgroundTask())
        application.onBegin = { handler in
            UIBackgroundTaskIdentifier(rawValue: 2)
        }
        XCTAssertFalse(backgroundHandler.beginBackgroundTask())
    }

    func testStartingThenEndingResetState() {
        application.onBegin = { handler in
            UIBackgroundTaskIdentifier(rawValue: 1)
        }
        XCTAssert(backgroundHandler.beginBackgroundTask())

        application.onEnd = { identifier in
            XCTAssertEqual(identifier.rawValue, 1)
        }
        XCTAssert(backgroundHandler.endBackgroundTask())
        XCTAssert(backgroundHandler.beginBackgroundTask())
        XCTAssert(backgroundHandler.endBackgroundTask())
    }

    func testEndingReturnsFalseIfTaskNotStarted() {
        XCTAssertFalse(backgroundHandler.endBackgroundTask())
    }

    func testHandlerEndsTaskIfCalled() {
        var handler: (() -> Void)?
        application.onBegin = { h in
            handler = h
            return UIBackgroundTaskIdentifier(rawValue: 1)
        }
        XCTAssert(backgroundHandler.beginBackgroundTask())
        XCTAssertNotNil(handler)
        handler?()
        XCTAssertFalse(backgroundHandler.endBackgroundTask())
    }
}
