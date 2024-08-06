//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import XCTest
@testable import SwiftAudioKit

class URL_Offline_Tests: XCTestCase {
    func testOfflineURLs() {
        XCTAssertTrue(URL(fileURLWithPath: "/home/xxx").ap_isOfflineURL)
        XCTAssertTrue(URL(string: "http://localhost://")!.ap_isOfflineURL)
        XCTAssertTrue(URL(string: "http://127.0.0.1/xxx")!.ap_isOfflineURL)
    }

    func testOnlineURL() {
        XCTAssertFalse(URL(string: "http://google.com")!.ap_isOfflineURL)
        XCTAssertFalse(URL(string: "http://apple.com")!.ap_isOfflineURL)
    }
}
