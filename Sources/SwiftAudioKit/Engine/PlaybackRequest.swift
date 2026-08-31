//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation

struct PlaybackRequest: Sendable, Hashable {
    var url: URL
    var startTime: Duration?
    var preferredForwardBufferDuration: Duration?
    var preferredPeakBitRate: Double?
    /// Radio servers routinely mislabel their streams, which stops AVFoundation picking a parser.
    var overrideMIMEType: String?
    var httpUserAgent: String?

    init(
        url: URL,
        startTime: Duration? = nil,
        preferredForwardBufferDuration: Duration? = nil,
        preferredPeakBitRate: Double? = nil,
        overrideMIMEType: String? = nil,
        httpUserAgent: String? = nil
    ) {
        self.url = url
        self.startTime = startTime
        self.preferredForwardBufferDuration = preferredForwardBufferDuration
        self.preferredPeakBitRate = preferredPeakBitRate
        self.overrideMIMEType = overrideMIMEType
        self.httpUserAgent = httpUserAgent
    }
}

struct SeekTolerance: Sendable, Hashable {
    var before: Duration?
    var after: Duration?

    /// Seeks to the nearest sync sample, which is fast but lands off the requested time.
    static let relaxed = SeekTolerance(before: nil, after: nil)
    static let exact = SeekTolerance(before: .zero, after: .zero)
}
