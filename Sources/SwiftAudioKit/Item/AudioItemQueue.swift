//
//  SwiftAudioKit
//
//  Created by Dionysios Karatzas.
//  Copyright © 2024 Dionysios Karatzas. All rights reserved.
//

import Foundation

// MARK: - AudioItemQueueDelegate

/// `AudioItemQueueDelegate` defines the behavior of `AudioItem` in certain circumstances and is notified upon notable events.
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

    /// The historic of items played in the queue.
    private(set) var historic: [AudioItem] = []

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
        self.queue = mode.contains(.shuffle) ? items.shuffled() : items
    }

    /// Adapts the queue to the new mode.
    ///
    /// - Parameter oldMode: The mode before it changed.
    private func adaptQueue(oldMode: AudioPlayerMode) {
        guard !queue.isEmpty else { return }

        if oldMode.contains(.repeat) && !mode.contains(.repeat), historic.last == queue[safe: nextPosition] {
            nextPosition += 1
        } else if !oldMode.contains(.repeat), mode.contains(.repeat), nextPosition >= queue.count {
            nextPosition = max(0, queue.count - 1)
        }

        if oldMode.contains(.shuffle) && !mode.contains(.shuffle) {
            queue = items
            if let lastItem = historic.last, let index = queue.firstIndex(of: lastItem) {
                nextPosition = index + 1
            }
        } else if mode.contains(.shuffle), !oldMode.contains(.shuffle) {
            let alreadyPlayed = queue.prefix(nextPosition)
            let leftovers = queue.suffix(from: nextPosition)
            queue = Array(alreadyPlayed) + leftovers.shuffled()
        }
    }

    /// Returns the next item in the queue.
    ///
    /// - Returns: The next item in the queue.
    func nextItem() -> AudioItem? {
        guard !queue.isEmpty else { return nil }

        if mode.contains(.repeat) {
            let item = queue[safe: nextPosition] ?? queue.last
            historic.append(item!)
            return item
        }

        if mode.contains(.repeatAll) && nextPosition >= queue.count {
            nextPosition = 0
        }

        while nextPosition < queue.count {
            let item = queue[nextPosition]
            nextPosition += 1

            if shouldConsiderItem(item: item) {
                historic.append(item)
                return item
            }
        }

        if mode.contains(.repeatAll), nextPosition >= queue.count {
            nextPosition = 0
        }

        return nil
    }

    /// A boolean value indicating whether the queue has a next item to play or not.
    var hasNextItem: Bool {
        return !queue.isEmpty && (nextPosition < queue.count || mode.contains(.repeat) || mode.contains(.repeatAll))
    }

    /// Returns the previous item in the queue.
    ///
    /// - Returns: The previous item in the queue.
    func previousItem() -> AudioItem? {
        guard !queue.isEmpty else { return nil }

        if mode.contains(.repeat) {
            let item = queue[max(0, nextPosition - 1)]
            historic.append(item)
            return item
        }

        if mode.contains(.repeatAll), nextPosition <= 0 {
            nextPosition = queue.count
        }

        while nextPosition > 0 {
            nextPosition -= 1
            let item = queue[nextPosition]

            if shouldConsiderItem(item: item) {
                historic.append(item)
                return item
            }
        }

        if mode.contains(.repeatAll), nextPosition <= 0 {
            nextPosition = queue.count
        }

        return nil
    }

    /// A boolean value indicating whether the queue has a previous item to play or not.
    var hasPreviousItem: Bool {
        return !queue.isEmpty && (nextPosition > 0 || mode.contains(.repeat) || mode.contains(.repeatAll))
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
        guard queue.indices.contains(index) else { return }
        let item = queue.remove(at: index)
        items.removeAll { $0 == item }
    }

    /// Returns a boolean value indicating whether an item should be considered playable in the queue.
    ///
    /// - Parameter item: The item to check.
    /// - Returns: A boolean value indicating whether an item should be considered playable in the queue.
    private func shouldConsiderItem(item: AudioItem) -> Bool {
        return delegate?.audioItemQueue(self, shouldConsiderItem: item) ?? true
    }
}

// MARK: - Safe Array Access

private extension Array {
    /// Safely access array element.
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
