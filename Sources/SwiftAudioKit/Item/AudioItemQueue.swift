//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

// MARK: - AudioItemQueueDelegate

/// `AudioItemQueueDelegate` defines the behavior of `AudioItem` in certain circumstances and is notified upon notable
/// events.
protocol AudioItemQueueDelegate: AnyObject {
    /// Returns a boolean value indicating whether an item should be considered playable in the queue.
    ///
    /// - Parameters:
    ///   - queue: The queue.
    ///   - item: The item we ask the information for.
    /// - Returns: A boolean value indicating whether an item should be considered playable in the queue.
    func audioItemQueue(_ queue: AudioItemQueue, shouldConsiderItem item: AudioItem) -> Bool
}

// MARK: - AudioItemQueue

/// `AudioItemQueue` handles queueing items with a playing mode.
class AudioItemQueue {
    /// The original items, keeping the same order.
    private(set) var items: [AudioItem]

    /// The items stored in the way the mode requires.
    private(set) var queue: [AudioItem]

    /// The history of items played in the queue.
    private(set) var historic: [AudioItem]

    /// The current position in the queue.
    var nextPosition = 0

    /// The player mode. It will affect the queue.
    var mode: AudioPlayerMode {
        didSet {
            adaptQueue(oldMode: oldValue)
        }
    }

    /// The queue delegate.
    weak var delegate: AudioItemQueueDelegate?

    /// Initializes a queue with a list of items and the mode.
    ///
    /// - Parameters:
    ///   - items: The list of items to play.
    ///   - mode: The mode to play items with.
    init(items: [AudioItem], mode: AudioPlayerMode) {
        self.items = items
        self.mode = mode
        queue = mode.contains(.shuffle) ? items.shuffled() : items
        historic = []
    }

    /// Adapts the queue to the new mode.
    ///
    /// Behavior is:
    /// - If `oldMode` contains .repeat and `mode` doesn't, and the last item played is the next item, increment position.
    /// - If `oldMode` contains .shuffle and `mode` doesn’t, set the queue to `items` and set the current position to the
    ///   current item's index in the new queue.
    /// - If `mode` contains .shuffle and `oldMode` doesn't, shuffle the leftover items in the queue.
    ///
    /// Note: The items already played will be shuffled at the beginning of the queue, while the leftovers will be shuffled at
    /// the end of the array.
    ///
    /// - Parameter oldMode: The mode before it changed.
    private func adaptQueue(oldMode: AudioPlayerMode) {
        // Early exit if queue is empty
        guard !queue.isEmpty else {
            return
        }

        // Handle repeatAll mode adaptation
        if !oldMode.contains(.repeatAll), mode.contains(.repeatAll) {
            nextPosition = nextPosition % queue.count
        }

        // Handle transition out of repeat mode
        if oldMode.contains(.repeat), !mode.contains(.repeat), historic.last == queue[nextPosition] {
            nextPosition += 1
        } else if !oldMode.contains(.repeat), mode.contains(.repeat), nextPosition == queue.count {
            nextPosition -= 1
        }

        // Handle transition out of shuffle mode
        if oldMode.contains(.shuffle), !mode.contains(.shuffle) {
            queue = items
            if let last = historic.last, let index = queue.firstIndex(of: last) {
                nextPosition = index + 1
            }
        }
        // Handle transition into shuffle mode
        else if mode.contains(.shuffle), !oldMode.contains(.shuffle) {
            let alreadyPlayed = queue.prefix(upTo: nextPosition)
            let leftovers = queue.suffix(from: nextPosition)
            queue = Array(alreadyPlayed).shuffled() + Array(leftovers).shuffled()
        }
    }

    /// Returns the next item in the queue.
    ///
    /// - Returns: The next item in the queue, or `nil` if there are no more items.
    func nextItem() -> AudioItem? {
        // Early exit if queue is empty
        guard !queue.isEmpty else {
            return nil
        }

        // Handle repeat mode
        if mode.contains(.repeat) {
            let item = queue[nextPosition]
            historic.append(item)
            return item
        }

        // Handle repeatAll mode when reaching the end of the queue
        if mode.contains(.repeatAll), nextPosition >= queue.count {
            nextPosition = 0
        }

        // Find the next playable item in the queue
        while nextPosition < queue.count {
            let item = queue[nextPosition]
            nextPosition += 1

            if shouldConsiderItem(item: item) {
                historic.append(item)
                return item
            }
        }

        // Reset position if in repeatAll mode and end of queue is reached
        if mode.contains(.repeatAll), nextPosition >= queue.count {
            nextPosition = 0
        }
        return nil
    }

    /// A boolean value indicating whether the queue has a next item to play or not.
    var hasNextItem: Bool {
        if !queue.isEmpty,
           queue.count > nextPosition || mode.contains(.repeat) || mode.contains(.repeatAll) {
            return true
        }
        return false
    }

    /// Returns the previous item in the queue.
    ///
    /// - Returns: The previous item in the queue, or `nil` if there are no previous items.
    func previousItem() -> AudioItem? {
        // Early exit if queue is empty
        guard !queue.isEmpty else {
            return nil
        }

        // Handle repeat mode
        if mode.contains(.repeat) {
            let item = queue[max(0, nextPosition - 1)]
            historic.append(item)
            return item
        }

        // Handle repeatAll mode when at the beginning of the queue
        if mode.contains(.repeatAll), nextPosition <= 0 {
            nextPosition = queue.count
        }

        // Find the previous playable item in the queue
        while nextPosition > 0 {
            var previousPosition = nextPosition - 1
            nextPosition = previousPosition
            if previousPosition == queue.count - 1, mode == .normal {
                previousPosition -= 1
            }
            let item = queue[previousPosition]
            if shouldConsiderItem(item: item) {
                historic.append(item)
                return item
            }
        }

        // Reset position if in repeatAll mode and beginning of queue is reached
        if mode.contains(.repeatAll), nextPosition <= 0 {
            nextPosition = queue.count
        }
        return nil
    }

    /// A boolean value indicating whether the queue has a previous item to play or not.
    var hasPreviousItem: Bool {
        if !queue.isEmpty,
           nextPosition > 1 || mode.contains(.repeat) || mode.contains(.repeatAll) {
            return true
        }
        return false
    }

    /// Adds a list of items to the queue.
    ///
    /// - Parameter items: The items to add to the queue.
    func add(items: [AudioItem]) {
        self.items.append(contentsOf: items)
        self.queue.append(contentsOf: items)
    }

    /// Removes an item from the queue.
    ///
    /// - Parameter index: The index of the item to remove.
    func remove(at index: Int) {
        let item = queue.remove(at: index)
        if let index = items.firstIndex(of: item) {
            items.remove(at: index)
        }
    }

    /// Returns a boolean value indicating whether an item should be considered playable in the queue.
    ///
    /// - Parameter item: The item to check.
    /// - Returns: A boolean value indicating whether the item should be considered playable.
    private func shouldConsiderItem(item: AudioItem) -> Bool {
        delegate?.audioItemQueue(self, shouldConsiderItem: item) ?? true
    }
}
