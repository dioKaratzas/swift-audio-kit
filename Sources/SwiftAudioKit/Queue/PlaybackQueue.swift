//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

/// An ordered list of tracks with a cursor, a playback order, and a history.
///
/// ``AudioPlayer`` owns one of these and exposes the operations you normally need —
/// ``AudioPlayer/append(_:)-(AudioItem)``, ``AudioPlayer/insertNext(_:)``,
/// ``AudioPlayer/move(from:to:)`` and the rest — so reach for this type directly only when
/// building a queue outside a player.
///
/// ``items`` holds tracks in the order they were added; ``order`` holds the order they play
/// in, which shuffling rewrites. ``currentIndex`` indexes ``order``, not ``items``.
///
/// - Important: Identifiers are unique. Appending or inserting an item whose ``AudioItem/id``
///   is already queued does nothing at all, silently.
public struct PlaybackQueue: Sendable, Equatable {
    /// The tracks in the order they were added.
    ///
    /// Not the playback order once shuffled; see ``order``.
    public private(set) var items: [AudioItem]

    /// The playback order, as identifiers into ``items``.
    ///
    /// Rewritten by ``reshuffle(using:)`` and by turning shuffle on or off through ``mode``.
    public private(set) var order: [AudioItem.ID]

    /// Where the cursor sits within ``order``.
    ///
    /// - Important: This indexes ``order``, not ``items``, so it is not a position in the list
    ///   you supplied once shuffle is on. `nil` until something starts playing.
    public private(set) var currentIndex: Int?

    /// A record of what has played, oldest first.
    ///
    /// - Note: ``retreat(skipping:)`` walks ``order`` rather than this, so going back does not
    ///   retrace the history. The history is a log, not a navigation stack.
    public private(set) var history: [AudioItem.ID]

    /// How many identifiers ``history`` keeps.
    ///
    /// Lowering it trims the oldest entries immediately.
    public var historyLimit: Int {
        didSet { trimHistory() }
    }

    /// The repeat and shuffle settings the queue traverses under.
    ///
    /// Turning shuffle on or off reorders what is left to play while holding the current track
    /// in place, so the track playing does not change under the listener.
    public var mode: PlaybackMode {
        didSet { adapt(from: oldValue) }
    }

    /// Creates a queue.
    ///
    /// - Parameters:
    ///   - items: The tracks to queue, in the order they should be recorded. Defaults to
    ///     empty. Duplicate identifiers are kept as supplied; deduplication applies to later
    ///     appends.
    ///   - mode: The repeat and shuffle settings. Defaults to ``PlaybackMode/normal``. When it
    ///     says shuffled, the order is shuffled straight away.
    ///   - historyLimit: How many identifiers ``history`` keeps. Defaults to `128`.
    ///
    /// - Note: Nothing is current until something starts, so ``currentIndex`` begins `nil`.
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

    /// Whether nothing is queued.
    ///
    /// Also true after ``removeAll()``.
    public var isEmpty: Bool {
        order.isEmpty
    }

    /// How many tracks are queued, skipped ones included.
    public var count: Int {
        order.count
    }

    /// The track the cursor sits on, or `nil` before anything has started.
    public var current: AudioItem? {
        guard let currentIndex, order.indices.contains(currentIndex) else {
            return nil
        }
        return self[order[currentIndex]]
    }

    /// What follows the cursor in playback order, excluding the current track.
    ///
    /// The whole queue when nothing has started yet. Skipped tracks are included, because the
    /// skip set belongs to the player rather than the queue.
    public var upNext: [AudioItem] {
        let start = currentIndex.map { $0 + 1 } ?? 0
        guard start < order.count else {
            return []
        }
        return order[start...].compactMap { self[$0] }
    }

    /// Looks a track up by identifier, wherever it sits in the queue.
    ///
    /// - Parameter id: The identifier to find.
    /// - Returns: The queued track with that identifier, or `nil` when it is not queued.
    public subscript(id: AudioItem.ID) -> AudioItem? {
        items.first { $0.id == id }
    }

    // MARK: Traversal

    /// Returns whether ``advance(skipping:)`` would find a track.
    ///
    /// - Parameter skipped: Identifiers to step over. Defaults to empty.
    /// - Returns: `true` when there is somewhere to advance to. Always `true` under
    ///   ``RepeatMode/all`` and ``RepeatMode/one`` while anything is queued, since neither ever
    ///   runs out.
    public func hasNext(skipping skipped: Set<AudioItem.ID> = []) -> Bool {
        peekNext(skipping: skipped) != nil
    }

    /// Returns whether ``retreat(skipping:)`` would find a track.
    ///
    /// - Parameter skipped: Identifiers to step over. Defaults to empty.
    /// - Returns: `true` when there is somewhere to go back to. Always `false` before anything
    ///   has started, since there is no cursor to step back from.
    public func hasPrevious(skipping skipped: Set<AudioItem.ID> = []) -> Bool {
        peekPrevious(skipping: skipped) != nil
    }

    /// Moves the cursor forward and returns what it landed on.
    ///
    /// Wraps to the front under ``RepeatMode/all``, and stays put under ``RepeatMode/one``.
    ///
    /// - Parameter skipped: Identifiers to step over. Defaults to empty. A skipped track is
    ///   passed by, not removed.
    /// - Returns: The track the cursor landed on, or `nil` when the queue has run out — which
    ///   under ``RepeatMode/off`` means every remaining track was skipped or there were none.
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

    /// Moves the cursor backward and returns what it landed on.
    ///
    /// Wraps to the end under ``RepeatMode/all``, and stays put under ``RepeatMode/one``.
    ///
    /// - Parameter skipped: Identifiers to step over. Defaults to empty.
    /// - Returns: The track the cursor landed on, or `nil` at the front of the queue and
    ///   before anything has started.
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

    /// Moves the cursor straight to a queued track.
    ///
    /// - Parameter id: The identifier of the track to jump to.
    /// - Returns: The track jumped to, or `nil` when nothing in the queue has that identifier.
    ///
    /// - Note: Ignores both ``mode`` and any skip set, because a jump is an explicit
    ///   instruction rather than a traversal.
    @discardableResult
    public mutating func jump(to id: AudioItem.ID) -> AudioItem? {
        guard let index = order.firstIndex(of: id) else {
            return nil
        }
        return move(to: index)
    }

    // MARK: Mutation

    /// Adds tracks to the end of the playback order.
    ///
    /// - Parameter newItems: The tracks to add. Any whose ``AudioItem/id`` is already queued
    ///   are dropped, so appending the same batch twice is a no-op rather than a duplication.
    public mutating func append(contentsOf newItems: [AudioItem]) {
        let unseen = newItems.filter { self[$0.id] == nil }
        items.append(contentsOf: unseen)
        order.append(contentsOf: unseen.map(\.id))
    }

    /// Adds one track to the end of the playback order.
    ///
    /// - Parameter item: The track to add. Ignored when its ``AudioItem/id`` is already queued.
    public mutating func append(_ item: AudioItem) {
        append(contentsOf: [item])
    }

    /// Inserts a track directly after the cursor.
    ///
    /// - Parameter item: The track to queue next. Ignored when its ``AudioItem/id`` is already
    ///   queued. Lands at the front when nothing has started.
    public mutating func insertNext(_ item: AudioItem) {
        guard self[item.id] == nil else {
            return
        }
        items.append(item)
        order.insert(item.id, at: currentIndex.map { $0 + 1 } ?? 0)
    }

    /// Removes a track from the queue and from the history.
    ///
    /// - Parameter id: The identifier of the track to remove. Doing nothing is the correct
    ///   outcome when nothing has that identifier.
    ///
    /// - Note: Removing the current track leaves the cursor on whatever slides into its slot,
    ///   or clears it when the queue empties.
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

    /// Moves a track within the playback order, carrying the cursor with it.
    ///
    /// - Parameters:
    ///   - source: The index in ``order`` to lift the track out of.
    ///   - destination: The index to insert it at, in the order **with the item already lifted
    ///     out**. This differs from SwiftUI's `onMove`, whose offset is one greater when
    ///     moving an item later; subtract one before calling.
    ///
    /// - Note: Does nothing when either index is out of bounds or the two are equal.
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

    /// Empties the queue.
    ///
    /// Drops the tracks, the playback order, the history and the cursor together.
    public mutating func removeAll() {
        items.removeAll()
        order.removeAll()
        history.removeAll()
        currentIndex = nil
    }

    /// Writes a changed track back under the same identity.
    ///
    /// The player uses this to fold discovered metadata into a queued track without disturbing
    /// playback.
    ///
    /// - Parameter item: The replacement, matched by its ``AudioItem/id``. Playback order and
    ///   the cursor are left untouched, and an identifier that is not queued is ignored.
    public mutating func update(_ item: AudioItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index] = item
    }

    /// Shuffles the tracks that have not played yet.
    ///
    /// Everything up to and including the cursor keeps its position, so the current track goes
    /// on playing and the history stays coherent.
    ///
    /// - Parameter generator: The random number generator to draw from. Pass a seeded
    ///   generator to make a shuffle reproducible in tests.
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
