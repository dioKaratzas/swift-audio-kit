# Getting Started

Add the package, play a queue, and drive a SwiftUI view from the player's state.

## Install

SwiftAudioKit is distributed through Swift Package Manager. In Xcode, choose
**File > Add Package Dependencies** and enter
`https://github.com/dioKaratzas/swift-audio-kit`.

To depend on it from another package, add it to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/dioKaratzas/swift-audio-kit", from: "2.0.0")
]
```

and then to the target that uses it:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "SwiftAudioKit", package: "swift-audio-kit")
    ]
)
```

## Play a queue

An ``AudioItem`` pairs one or more stream URLs with the metadata you already know.
Handing several of them to ``AudioPlayer/play(_:startingAt:)`` loads the first and
queues the rest.

```swift
import SwiftAudioKit

let player = AudioPlayer(configuration: .podcast, remoteCommands: .default)

player.play([
    AudioItem(url: firstURL, metadata: AudioMetadata(title: "Episode 1", artist: "The Show")),
    AudioItem(url: secondURL, metadata: AudioMetadata(title: "Episode 2", artist: "The Show"))
])
```

``AudioPlayerConfiguration/podcast`` and ``AudioPlayerConfiguration/liveRadio`` are
presets. Build an ``AudioPlayerConfiguration`` directly to set the retry, buffering,
quality and audio session policies yourself.

The queue is edited through the player, which keeps the current track and the
playback order in step:

```swift
player.append(nextEpisode)
player.insertNext(trailer)          // plays after the current track
player.move(from: 3, to: 0)
player.remove(oldEpisode.id)
player.play(someItem.id)            // jump straight to a queued track

player.repeatMode = .all
player.isShuffled = true
```

``AudioPlayer/upNext`` holds what follows the current track, and
``AudioPlayer/hasNext`` and ``AudioPlayer/hasPrevious`` say whether
``AudioPlayer/next()`` and ``AudioPlayer/previous()`` would do anything.

When a track is available at several bitrates, describe it with ``AudioSources``
and let the player pick according to ``AudioPlayerConfiguration/quality``:

```swift
if let sources = AudioSources([.low: lowBitrateURL, .high: highBitrateURL]) {
    player.append(AudioItem(sources: sources, metadata: AudioMetadata(title: "Live")))
}
```

Call ``AudioPlayer/prepareForPlayback()`` before the first track if you want a
conflict over the audio session to surface as a thrown ``AudioPlayerError`` rather
than as silence:

```swift
try await player.prepareForPlayback()
```

## Observe state in SwiftUI

``AudioPlayer`` is `@Observable`, so a view that reads its properties is invalidated
when they change. There is nothing to subscribe to and nothing to mirror into
`@State`.

```swift
import SwiftAudioKit
import SwiftUI

@main
struct ExampleApp: App {
    @State private var player = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            NowPlayingView(player: player)
        }
    }
}

struct NowPlayingView: View {
    let player: AudioPlayer

    var body: some View {
        VStack(spacing: 12) {
            Text(player.currentItem?.displayTitle ?? "Nothing playing")
                .font(.headline)

            if let subtitle = player.metadata.subtitle {
                Text(subtitle)
                    .font(.subheadline)
            }

            ProgressView(value: player.progress.fraction ?? 0)

            HStack(spacing: 24) {
                Button("Previous", action: player.previous)
                    .disabled(!player.hasPrevious)

                Button(player.state.isPlaying ? "Pause" : "Play", action: player.togglePlayPause)

                Button("Next", action: player.next)
                    .disabled(!player.hasNext)
            }

            if player.state.isTransient {
                ProgressView()
            }
        }
    }
}
```

``AudioPlayer/state`` carries the current ``AudioItem`` along with the case, so a
view can read the track and the phase from one value. ``PlaybackState/isTransient``
covers loading, buffering and waiting for a connection — the cases worth showing a
spinner for. ``PlaybackProgress/fraction`` is `nil` for live streams, which have no
end to measure against.

## React to events

State describes the present. Things that happen once — a track finishing, the queue
running out, quality changing, an error that was recovered from — arrive as
``AudioPlayerEvent`` values on ``AudioPlayer/events``:

```swift
.task {
    for await event in player.events {
        switch event {
        case .queueExhausted:
            loadMoreEpisodes()
        case let .failed(error):
            show(error)
        default:
            break
        }
    }
}
```

Each access to ``AudioPlayer/events`` returns a new stream, so several observers can
read events independently.

## Next steps

- <doc:Concurrency>
