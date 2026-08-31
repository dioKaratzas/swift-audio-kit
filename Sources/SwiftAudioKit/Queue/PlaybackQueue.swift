//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

public struct PlaybackQueue: Sendable, Equatable {
    public private(set) var items: [AudioItem]
    public private(set) var order: [AudioItem.ID]
    public private(set) var currentIndex: Int?
    public private(set) var history: [AudioItem.ID]

    public var historyLimit: Int {
        didSet { trimHistory() }
    }

    public var mode: PlaybackMode {
        didSet { adapt(from: oldValue) }
    }

    public init(items: [AudioItem] = [], mode: PlaybackMode = .normal, historyLimit: Int = 128) {
        self.items = items
        self.mode = mode
        self.historyLimit = historyLimit
        order = items.map(\.id)
        history = []

        if mode.isShuffled {
            order.shuffle()
        }
    }

    public var isEmpty: Bool {
        order.isEmpty
    }

    public var count: Int {
        order.count
    }

    public var current: AudioItem? {
        guard let currentIndex, order.indices.contains(currentIndex) else {
            return nil
        }
        return self[order[currentIndex]]
    }

    public var upNext: [AudioItem] {
        let start = currentIndex.map { $0 + 1 } ?? 0
        guard start < order.count else {
            return []
        }
        return order[start...].compactMap { self[$0] }
    }

    public subscript(id: AudioItem.ID) -> AudioItem? {
        items.first { $0.id == id }
    }

    // MARK: Traversal

    public func hasNext(skipping skipped: Set<AudioItem.ID> = []) -> Bool {
        peekNext(skipping: skipped) != nil
    }

    public func hasPrevious(skipping skipped: Set<AudioItem.ID> = []) -> Bool {
        peekPrevious(skipping: skipped) != nil
    }

    @discardableResult
    public mutating func advance(skipping skipped: Set<AudioItem.ID> = []) -> AudioItem? {
        if mode.repeatMode == .one, let current {
            return current
        }
        guard let index = peekNext(skipping: skipped) else {
            return nil
        }
        return move(to: index)
    }

    @discardableResult
    public mutating func retreat(skipping skipped: Set<AudioItem.ID> = []) -> AudioItem? {
        if mode.repeatMode == .one, let current {
            return current
        }
        guard let index = peekPrevious(skipping: skipped) else {
            return nil
        }
        return move(to: index)
    }

    @discardableResult
    public mutating func jump(to id: AudioItem.ID) -> AudioItem? {
        guard let index = order.firstIndex(of: id) else {
            return nil
        }
        return move(to: index)
    }

    // MARK: Mutation

    public mutating func append(contentsOf newItems: [AudioItem]) {
        let unseen = newItems.filter { self[$0.id] == nil }
        items.append(contentsOf: unseen)
        order.append(contentsOf: unseen.map(\.id))
    }

    public mutating func append(_ item: AudioItem) {
        append(contentsOf: [item])
    }

    public mutating func insertNext(_ item: AudioItem) {
        guard self[item.id] == nil else {
            return
        }
        items.append(item)
        order.insert(item.id, at: currentIndex.map { $0 + 1 } ?? 0)
    }

    public mutating func remove(id: AudioItem.ID) {
        guard let index = order.firstIndex(of: id) else {
            return
        }
        order.remove(at: index)
        items.removeAll { $0.id == id }
        history.removeAll { $0 == id }

        guard let current = currentIndex else {
            return
        }
        if index < current {
            currentIndex = current - 1
        } else if index == current {
            currentIndex = order.isEmpty ? nil : min(current, order.count - 1)
        }
    }

    public mutating func move(from source: Int, to destination: Int) {
        guard order.indices.contains(source), order.indices.contains(destination), source != destination else {
            return
        }
        let moved = order.remove(at: source)
        order.insert(moved, at: destination)

        if currentIndex == source {
            currentIndex = destination
        } else if let current = currentIndex {
            let shifted = current - (source < current ? 1 : 0) + (destination <= current ? 1 : 0)
            currentIndex = shifted
        }
    }

    public mutating func removeAll() {
        items.removeAll()
        order.removeAll()
        history.removeAll()
        currentIndex = nil
    }

    /// Writes a changed payload back under the same identity, leaving order and cursor untouched.
    public mutating func update(_ item: AudioItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index] = item
    }

    public mutating func reshuffle(using generator: inout some RandomNumberGenerator) {
        let played = currentIndex.map { order[...$0] } ?? []
        var remaining = Array(currentIndex.map { order[($0 + 1)...] } ?? order[...])
        remaining.shuffle(using: &generator)
        order = Array(played) + remaining
    }

    // MARK: Private

    private func peekNext(skipping skipped: Set<AudioItem.ID>) -> Int? {
        if mode.repeatMode == .one, currentIndex != nil {
            return currentIndex
        }
        let start = currentIndex.map { $0 + 1 } ?? 0
        if let index = firstPlayableIndex(in: start ..< order.count, skipping: skipped) {
            return index
        }
        guard mode.repeatMode == .all else {
            return nil
        }
        return firstPlayableIndex(in: 0 ..< min(start, order.count), skipping: skipped)
    }

    private func peekPrevious(skipping skipped: Set<AudioItem.ID>) -> Int? {
        guard let currentIndex else {
            return nil
        }
        if mode.repeatMode == .one {
            return currentIndex
        }
        if let index = lastPlayableIndex(in: 0 ..< currentIndex, skipping: skipped) {
            return index
        }
        guard mode.repeatMode == .all else {
            return nil
        }
        return lastPlayableIndex(in: (currentIndex + 1) ..< order.count, skipping: skipped)
    }

    private func firstPlayableIndex(in range: Range<Int>, skipping skipped: Set<AudioItem.ID>) -> Int? {
        range.first { !skipped.contains(order[$0]) }
    }

    private func lastPlayableIndex(in range: Range<Int>, skipping skipped: Set<AudioItem.ID>) -> Int? {
        range.reversed().first { !skipped.contains(order[$0]) }
    }

    private mutating func move(to index: Int) -> AudioItem? {
        guard order.indices.contains(index), let item = self[order[index]] else {
            return nil
        }
        currentIndex = index
        history.append(item.id)
        trimHistory()
        return item
    }

    private mutating func trimHistory() {
        guard history.count > historyLimit else {
            return
        }
        history.removeFirst(history.count - historyLimit)
    }

    private mutating func adapt(from old: PlaybackMode) {
        guard old.isShuffled != mode.isShuffled, !order.isEmpty else {
            return
        }
        let anchor = current?.id

        if mode.isShuffled {
            var generator = SystemRandomNumberGenerator()
            reshuffle(using: &generator)
        } else {
            order = items.map(\.id)
        }

        currentIndex = anchor.flatMap { order.firstIndex(of: $0) }
    }
}
