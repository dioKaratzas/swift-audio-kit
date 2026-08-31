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

    var supportsAudioProcessing: Bool {
        // From OS 27 a mix can name the mix of all audio tracks rather than one track, which is
        // the only way to tap a stream that exposes no track of its own.
        if #available(macOS 27, iOS 27, tvOS 27, visionOS 27, *) {
            return true
        }
        return !url.isHLSPlaylist
    }
}

struct SeekTolerance: Sendable, Hashable {
    var before: Duration?
    var after: Duration?

    /// Seeks to the nearest sync sample, which is fast but lands off the requested time.
    static let relaxed = SeekTolerance(before: nil, after: nil)
    static let exact = SeekTolerance(before: .zero, after: .zero)
}
