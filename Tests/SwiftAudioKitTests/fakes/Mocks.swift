//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import UIKit
import AVFoundation
@testable import SwiftAudioKit
import SystemConfiguration

class MockEventListener: EventListener {
    var eventClosure: ((Event, EventProducer) -> Void)?

    func onEvent(_ event: Event, generatedBy eventProducer: EventProducer) {
        eventClosure?(event, eventProducer)
    }
}

class MockReachability: Reachability {
    var reachabilityStatus = Reachability.NetworkStatus.notReachable {
        didSet {
            NotificationCenter.default.post(name: .ReachabilityChanged, object: self)
        }
    }

    override var currentReachabilityStatus: Reachability.NetworkStatus {
        reachabilityStatus
    }
}

class MockItem: AVPlayerItem {
    var bufferEmpty = true {
        willSet {
            willChangeValue(forKey: #keyPath(AVPlayerItem.isPlaybackBufferEmpty))
        }
        didSet {
            didChangeValue(forKey: #keyPath(AVPlayerItem.isPlaybackBufferEmpty))
        }
    }

    override var isPlaybackBufferEmpty: Bool {
        bufferEmpty
    }

    var likelyToKeepUp = false {
        willSet {
            willChangeValue(forKey: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp))
        }
        didSet {
            didChangeValue(forKey: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp))
        }
    }

    override var isPlaybackLikelyToKeepUp: Bool {
        likelyToKeepUp
    }

    var timeRanges = [NSValue]() {
        willSet {
            willChangeValue(forKey: #keyPath(AVPlayerItem.loadedTimeRanges))
        }
        didSet {
            didChangeValue(forKey: #keyPath(AVPlayerItem.loadedTimeRanges))
        }
    }

    override var loadedTimeRanges: [NSValue] {
        timeRanges
    }

    var stat = AVPlayerItem.Status.unknown {
        willSet {
            willChangeValue(forKey: #keyPath(AVPlayerItem.status))
        }
        didSet {
            didChangeValue(forKey: #keyPath(AVPlayerItem.status))
        }
    }

    override var status: AVPlayerItem.Status {
        stat
    }

    var dur = CMTime() {
        willSet {
            willChangeValue(forKey: #keyPath(AVPlayerItem.duration))
        }
        didSet {
            didChangeValue(forKey: #keyPath(AVPlayerItem.duration))
        }
    }

    override var duration: CMTime {
        dur
    }
}

private extension Selector {
    static let mockPlayerTimerTicked = #selector(MockPlayer.timerTicked(_:))
}

class MockPlayer: AVPlayer {
    var timer: Timer?
    var startDate: NSDate?
    var observerClosure: ((CMTime) -> Void)?
    var item: MockItem? {
        willSet {
            willChangeValue(forKey: #keyPath(currentItem))
        }
        didSet {
            didChangeValue(forKey: #keyPath(currentItem))
        }
    }

    override var currentItem: AVPlayerItem? {
        item
    }

    override func addPeriodicTimeObserver(
        forInterval interval: CMTime,
        queue: DispatchQueue?,
        using block: @escaping (CMTime) -> Void
    ) -> Any {
        observerClosure = block
        startDate = NSDate()
        timer = Timer.scheduledTimer(
            timeInterval: CMTimeGetSeconds(interval),
            target: self,
            selector: .mockPlayerTimerTicked,
            userInfo: nil,
            repeats: true
        )
        return self
    }

    override func removeTimeObserver(_ observer: Any) {
        timer?.invalidate()
        timer = nil
        startDate = nil
        observerClosure = nil
    }

    @objc
    fileprivate func timerTicked(_: Timer) {
        let t = fabs(startDate!.timeIntervalSinceNow)
        observerClosure?(CMTime(timeInterval: t))
    }
}

class MockMetadataItem: AVMetadataItem {
    var _commonKey: AVMetadataKey
    var _value: NSCopying & NSObjectProtocol

    init(commonKey: AVMetadataKey, value: NSCopying & NSObjectProtocol) {
        _commonKey = commonKey
        _value = value
    }

    override var commonKey: AVMetadataKey? {
        _commonKey
    }

    override var value: NSCopying & NSObjectProtocol {
        _value
    }
}

class MockApplication: BackgroundTaskCreator {
    var onBegin: (((() -> Void)?) -> UIBackgroundTaskIdentifier)?
    var onEnd: ((UIBackgroundTaskIdentifier) -> Void)?

    func beginBackgroundTask(expirationHandler handler: (() -> Void)?) -> UIBackgroundTaskIdentifier {
        onBegin?(handler) ?? UIBackgroundTaskIdentifier.invalid
    }

    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        onEnd?(identifier)
    }
}

class MockAudioPlayer: AudioPlayer {
    var avPlayer = MockPlayer()

    override var player: AVPlayer? {
        get {
            avPlayer
        }
        set {}
    }
}

class MockAudioPlayerDelegate: AudioPlayerDelegate {
    var didChangeState: ((AudioPlayer, AudioPlayerState, AudioPlayerState) -> Void)?

    var willStartPlaying: ((AudioPlayer, AudioItem) -> Void)?

    var didUpdateProgression: ((AudioPlayer, TimeInterval, Float) -> Void)?

    var didLoadRange: ((AudioPlayer, TimeRange, AudioItem) -> Void)?

    var didFindDuration: ((AudioPlayer, TimeInterval, AudioItem) -> Void)?

    var didUpdateEmptyMetadata: ((AudioPlayer, AudioItem, Metadata) -> Void)?

    func audioPlayer(_ audioPlayer: AudioPlayer, didChangeStateFrom from: AudioPlayerState, to state: AudioPlayerState) {
        didChangeState?(audioPlayer, from, state)
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, willStartPlaying item: AudioItem) {
        willStartPlaying?(audioPlayer, item)
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, didUpdateProgressionTo time: TimeInterval, percentageRead: Float) {
        didUpdateProgression?(audioPlayer, time, percentageRead)
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, didLoad range: TimeRange, for item: AudioItem) {
        didLoadRange?(audioPlayer, range, item)
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, didFindDuration duration: TimeInterval, for item: AudioItem) {
        didFindDuration?(audioPlayer, duration, item)
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, didUpdateEmptyMetadataOn item: AudioItem, withData data: Metadata) {
        didUpdateEmptyMetadata?(audioPlayer, item, data)
    }
}
