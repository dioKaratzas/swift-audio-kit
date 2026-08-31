# Concurrency

How the player is isolated, what can cross an isolation boundary, and how events are
delivered.

## Overview

SwiftAudioKit is built for the Swift 6 language mode. The package compiles with
`-swift-version 6` and the `NonisolatedNonsendingByDefault` and `ExistentialAny`
upcoming features enabled, so the isolation described here is checked at compile
time rather than assumed.

## The player is main-actor isolated

``AudioPlayer`` is `@MainActor`. Every property and method on it is reached from the
main actor, which is where a UI reads them anyway. Creating a player, mutating the
queue and reading state all happen without hopping.

Nothing about that blocks the main thread. The work that takes time — loading an
asset, seeking, activating the audio session, watching the network path — runs
inside child tasks that suspend, and only the resulting state change is applied back
on the main actor. The asynchronous entry points are marked as such:

- ``AudioPlayer/seek(to:clampingToSeekableRange:)`` and ``AudioPlayer/seek(by:)``
- ``AudioPlayer/seekToStart(padding:)`` and ``AudioPlayer/seekToLiveEdge(padding:)``
- ``AudioPlayer/prepareForPlayback()``, which throws a typed ``AudioPlayerError``

If you own the player from a model of your own, isolate that model to the main actor
too:

```swift
@Observable
@MainActor
final class PlayerModel {
    let player = AudioPlayer()
}
```

## Observation replaces delegation

``AudioPlayer`` is `@Observable`. ``AudioPlayer/state``, ``AudioPlayer/progress``,
``AudioPlayer/metadata``, ``AudioPlayer/quality``, ``AudioPlayer/network`` and
``AudioPlayer/upNext`` are published properties: read them in a SwiftUI `body` and
the view is invalidated when they change. There is no delegate protocol, so there is
no object whose isolation you have to reason about.

## Models are Sendable value types

Everything the player hands out is a `Sendable` value type — ``AudioItem``,
``AudioSources``, ``AudioMetadata``, ``Artwork``, ``PlaybackState``,
``PlaybackProgress``, ``PlaybackQueue``, ``PlaybackMode``, ``NetworkStatus``,
``AudioPlayerConfiguration``, ``AudioPlayerError`` and ``PlaybackFailure`` among
them.

That has two consequences. A value read from the player is a snapshot: it will not
change underneath you, and it can be sent to another actor, stored in a background
task, or written to disk without copying it defensively.

It also means errors from AVFoundation are converted at the boundary.
``PlaybackFailure`` captures an `NSError`'s domain, code and message into a
`Sendable`, `Hashable` value where the error leaves AVFoundation, so failures can be
compared and carried across isolation boundaries.

``MetadataParser`` is a `Sendable` protocol, so a custom parser must be safe to
invoke from whichever context parses a stream's timed metadata. Keep implementations
free of mutable state, as ``DefaultMetadataParser`` is.

## Events arrive on an AsyncStream

``AudioPlayer/events`` is an `AsyncStream<AudioPlayerEvent>`. Each access to the
property creates a new stream with its own continuation, so several observers can
consume events independently — one shared continuation would starve the second
consumer.

```swift
let task = Task {
    for await event in player.events {
        handle(event)
    }
}
```

Each stream buffers the 64 most recent events, so a slow consumer drops the oldest
rather than applying backpressure to playback. Streams finish when the player is
deinitialised, which ends the `for await` loop. Cancel the task yourself if you want
to stop observing sooner.

``AudioPlayerEvent`` reports what happened at a point in time — a track finished,
the queue ran out, the duration resolved, an error was recovered from. Use
``AudioPlayer/state`` and the other observable properties for what is true now, and
events for what just occurred.
