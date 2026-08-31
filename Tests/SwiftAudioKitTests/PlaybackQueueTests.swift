//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Testing
import Foundation
@testable import SwiftAudioKit

@Suite("Playback queue")
struct PlaybackQueueTests {
    private let first = AudioItem(url: URL(string: "https://example.com/1.mp3")!)
    private let second = AudioItem(url: URL(string: "https://example.com/2.mp3")!)
    private let third = AudioItem(url: URL(string: "https://example.com/3.mp3")!)

    private var threeItems: [AudioItem] {
        [first, second, third]
    }

    private func queue(_ mode: PlaybackMode = .normal) -> PlaybackQueue {
        PlaybackQueue(items: threeItems, mode: mode)
    }

    // MARK: Traversal

    @Test
    func `An empty queue goes nowhere`() {
        var queue = PlaybackQueue()

        #expect(queue.isEmpty)
        #expect(!queue.hasNext())
        #expect(!queue.hasPrevious())
        #expect(queue.advance() == nil)
        #expect(queue.retreat() == nil)
        #expect(queue.current == nil)
    }

    @Test
    func `Advancing walks the queue once in normal mode`() {
        var queue = queue()

        #expect(queue.advance() == first)
        #expect(queue.advance() == second)
        #expect(queue.advance() == third)
        #expect(queue.advance() == nil)
        #expect(queue.current == third)
    }

    @Test
    func `Retreating walks back to the start and stops`() {
        var queue = queue()
        queue.advance()
        queue.advance()
        queue.advance()

        #expect(queue.retreat() == second)
        #expect(queue.retreat() == first)
        #expect(queue.retreat() == nil)
        #expect(queue.current == first)
    }

    @Test
    func `Availability agrees with traversal`() {
        var queue = queue()

        #expect(queue.hasNext())
        #expect(!queue.hasPrevious())

        queue.advance()
        #expect(queue.hasNext())
        #expect(!queue.hasPrevious())

        queue.advance()
        #expect(queue.hasNext())
        #expect(queue.hasPrevious())

        queue.advance()
        #expect(!queue.hasNext())
        #expect(queue.hasPrevious())
    }

    // MARK: Skipping

    @Test
    func `Skipped items are stepped over going forward`() {
        var queue = queue()
        let skip: Set = [second.id]

        #expect(queue.advance(skipping: skip) == first)
        #expect(queue.advance(skipping: skip) == third)
        #expect(queue.advance(skipping: skip) == nil)
    }

    @Test
    func `Skipped items are stepped over going backward`() {
        var queue = queue()
        let skip: Set = [second.id]
        queue.advance()
        queue.advance()
        queue.advance()

        #expect(queue.retreat(skipping: skip) == first)
    }

    @Test
    func `A fully skipped queue has nowhere to go`() {
        var queue = queue()
        let skip = Set(threeItems.map(\.id))

        #expect(!queue.hasNext(skipping: skip))
        #expect(queue.advance(skipping: skip) == nil)
    }

    @Test
    func `Availability accounts for skipped items`() {
        var queue = queue()
        queue.advance()

        #expect(!queue.hasNext(skipping: [second.id, third.id]))
        #expect(queue.hasNext(skipping: [second.id]))
    }

    // MARK: Repeat

    @Test
    func `Repeat one yields the same item indefinitely`() {
        var queue = queue(.repeatOne)
        queue.advance()

        for _ in 0 ..< 10 {
            #expect(queue.advance() == first)
        }
        #expect(queue.retreat() == first)
    }

    @Test
    func `Repeat one still needs a first advance to pick an item`() {
        var queue = queue(.repeatOne)

        #expect(queue.advance() == first)
    }

    @Test
    func `Repeat all wraps forward past the end`() {
        var queue = queue(.repeatAll)
        queue.advance()
        queue.advance()
        queue.advance()

        #expect(queue.hasNext())
        #expect(queue.advance() == first)
    }

    @Test
    func `Repeat all wraps backward past the start`() {
        var queue = queue(.repeatAll)
        queue.advance()

        #expect(queue.hasPrevious())
        #expect(queue.retreat() == third)
    }

    @Test
    func `Repeat all skips unavailable items while wrapping`() {
        var queue = queue(.repeatAll)
        let skip: Set = [first.id]
        queue.advance(skipping: skip)
        queue.advance(skipping: skip)

        #expect(queue.current == third)
        #expect(queue.advance(skipping: skip) == second)
    }

    // MARK: Shuffle

    @Test
    func `Shuffling keeps every item exactly once`() {
        let queue = queue(.shuffle)

        #expect(Set(queue.order) == Set(threeItems.map(\.id)))
        #expect(queue.order.count == threeItems.count)
    }

    @Test
    func `A seeded shuffle is reproducible`() {
        var left = queue()
        var right = queue()
        var leftGenerator = SplitMix64(seed: 42)
        var rightGenerator = SplitMix64(seed: 42)

        left.reshuffle(using: &leftGenerator)
        right.reshuffle(using: &rightGenerator)

        #expect(left.order == right.order)
        #expect(Set(left.order) == Set(threeItems.map(\.id)))
    }

    @Test
    func `Shuffling leaves played items where they are`() {
        var queue = queue()
        queue.advance()
        var generator = SplitMix64(seed: 7)

        queue.reshuffle(using: &generator)

        #expect(queue.order.first == first.id)
        #expect(queue.current == first)
    }

    @Test
    func `Leaving shuffle restores source order and keeps the current item`() {
        var queue = queue(.shuffle)
        queue.advance()
        let playing = queue.current

        queue.mode = .normal

        #expect(queue.order == threeItems.map(\.id))
        #expect(queue.current == playing)
    }

    @Test
    func `Entering shuffle keeps the current item`() {
        var queue = queue()
        queue.advance()
        queue.advance()

        queue.mode = .shuffle

        #expect(queue.current == second)
        #expect(Set(queue.order) == Set(threeItems.map(\.id)))
    }

    // MARK: Mutation

    @Test
    func `Appending adds to the end`() {
        var queue = PlaybackQueue(items: [first])

        queue.append(second)

        #expect(queue.order == [first.id, second.id])
        #expect(queue.count == 2)
    }

    @Test
    func `Appending an item already queued does nothing`() {
        var queue = PlaybackQueue(items: [first])

        queue.append(first)

        #expect(queue.count == 1)
    }

    @Test
    func `Inserting next puts an item straight after the current one`() {
        var queue = PlaybackQueue(items: [first, second])
        queue.advance()

        queue.insertNext(third)

        #expect(queue.order == [first.id, third.id, second.id])
        #expect(queue.advance() == third)
    }

    @Test
    func `Removing an item ahead leaves the cursor on the same track`() {
        var queue = queue()
        queue.advance()

        queue.remove(id: third.id)

        #expect(queue.current == first)
        #expect(queue.count == 2)
    }

    @Test
    func `Removing an item behind keeps the cursor on the same track`() {
        var queue = queue()
        queue.advance()
        queue.advance()

        queue.remove(id: first.id)

        #expect(queue.current == second)
    }

    @Test
    func `Removing the current item lands on what took its place`() {
        var queue = queue()
        queue.advance()

        queue.remove(id: first.id)

        #expect(queue.current == second)
    }

    @Test
    func `Removing the last remaining item clears the cursor`() {
        var queue = PlaybackQueue(items: [first])
        queue.advance()

        queue.remove(id: first.id)

        #expect(queue.current == nil)
        #expect(queue.isEmpty)
    }

    @Test
    func `Moving an item keeps the cursor on the same track`() {
        var queue = queue()
        queue.advance()
        queue.advance()

        queue.move(from: 1, to: 2)

        #expect(queue.current == second)
        #expect(queue.order == [first.id, third.id, second.id])
    }

    @Test
    func `Clearing empties everything`() {
        var queue = queue()
        queue.advance()

        queue.removeAll()

        #expect(queue.isEmpty)
        #expect(queue.current == nil)
        #expect(queue.history.isEmpty)
    }

    @Test
    func `Updating writes a new payload under the same identity`() {
        var queue = queue()
        queue.advance()
        var updated = first
        updated.metadata = AudioMetadata(title: "Resolved title")

        queue.update(updated)

        #expect(queue.current?.metadata.title == "Resolved title")
        #expect(queue.order == threeItems.map(\.id))
    }

    @Test
    func `Jumping moves straight to an item`() {
        var queue = queue()

        #expect(queue.jump(to: third.id) == third)
        #expect(queue.current == third)
        #expect(queue.jump(to: AudioItem.ID()) == nil)
    }

    // MARK: Up next and history

    @Test
    func `Up next lists what follows the current item`() {
        var queue = queue()

        #expect(queue.upNext == threeItems)

        queue.advance()
        #expect(queue.upNext == [second, third])

        queue.advance()
        queue.advance()
        #expect(queue.upNext.isEmpty)
    }

    @Test
    func `History records what was played`() {
        var queue = queue()
        queue.advance()
        queue.advance()

        #expect(queue.history == [first.id, second.id])
    }

    @Test
    func `History is bounded by its limit`() {
        var queue = PlaybackQueue(items: threeItems, mode: .repeatAll, historyLimit: 2)

        for _ in 0 ..< 10 {
            queue.advance()
        }

        #expect(queue.history.count == 2)
    }

    @Test
    func `Lowering the history limit trims immediately`() {
        var queue = queue()
        queue.advance()
        queue.advance()
        queue.advance()

        queue.historyLimit = 1

        #expect(queue.history == [third.id])
    }
}

/// Seeded generator so shuffle assertions do not depend on the system source.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
