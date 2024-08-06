//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation
import AVFoundation

public typealias TimeRange = (earliest: TimeInterval, latest: TimeInterval)

extension AudioPlayer {
    /// The current item progression or nil if no item.
    public var currentItemProgression: TimeInterval? {
        player?.currentItem?.currentTime().seconds
    }

    /// The current item duration or nil if no item or unknown duration.
    public var currentItemDuration: TimeInterval? {
        guard let duration = player?.currentItem?.duration, duration.isNumeric else {
            return nil
        }
        return duration.seconds
    }

    /// The current seekable range.
    public var currentItemSeekableRange: TimeRange? {
        guard let range = player?.currentItem?.seekableTimeRanges.last?.timeRangeValue else {
            if let currentItemProgression = currentItemProgression {
                // Return the current time if no seekable range is available
                return (currentItemProgression, currentItemProgression)
            }
            return nil
        }
        return (range.start.seconds, range.end.seconds)
    }

    /// The current loaded range.
    public var currentItemLoadedRange: TimeRange? {
        guard let range = player?.currentItem?.loadedTimeRanges.last?.timeRangeValue else {
            return nil
        }
        return (range.start.seconds, range.end.seconds)
    }

    /// The time interval ahead that is currently loaded.
    public var currentItemLoadedAhead: TimeInterval? {
        guard let loadedRange = currentItemLoadedRange,
              let currentTime = player?.currentTime().seconds,
              loadedRange.earliest <= currentTime else {
            return nil
        }
        return loadedRange.latest - currentTime
    }
}
