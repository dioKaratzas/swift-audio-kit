//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import CoreMedia

extension CMTime {
    /// Creates a `CMTime` instance from a time interval in seconds.
    ///
    /// This initializer allows you to create a `CMTime` object using a `TimeInterval`, which is a typealias for `Double`
    /// representing a time in seconds. The `CMTime` is initialized with a high precision timescale of `1_000_000_000`
    /// (one billion) to provide nanosecond accuracy.
    ///
    /// - Parameter timeInterval: The time interval in seconds.
    init(timeInterval: TimeInterval) {
        self.init(seconds: timeInterval, preferredTimescale: 1_000_000_000)
    }

    /// Converts the `CMTime` instance to a `TimeInterval`, if the `CMTime` is valid.
    ///
    /// This computed property returns the time represented by the `CMTime` as a `TimeInterval` (in seconds) if the
    /// `CMTime` is valid and does not represent an undefined value (e.g., NaN). If the `CMTime` is not valid, or if
    /// the time is NaN, this property returns `nil`.
    ///
    /// - Returns: A `TimeInterval` representing the time in seconds, or `nil` if the `CMTime` is invalid or NaN.
    var timeInterval: TimeInterval? {
        guard flags.contains(.valid) else {
            return nil
        }

        let seconds = CMTimeGetSeconds(self)
        return seconds.isNaN ? nil : TimeInterval(seconds)
    }
}
