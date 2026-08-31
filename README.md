# SwiftAudioKit

[![Swift](https://img.shields.io/badge/Swift-6.3-F05138.svg?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Catalyst-blue.svg)](#requirements)
[![CI](https://img.shields.io/github/actions/workflow/status/dioKaratzas/swift-audio-kit/ci.yml?label=CI)](https://github.com/dioKaratzas/swift-audio-kit/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/Documentation-DocC-1E88E5.svg)](https://diokaratzas.github.io/swift-audio-kit/documentation/swiftaudiokit/)
[![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey.svg)](LICENSE)

**An audio player for apps that stream.** Radio stations, podcasts, music libraries — anything where the
audio comes off the network rather than out of the bundle.

`AVPlayer` will happily play a URL. What it will not do is everything around that URL. A stream stalls
halfway through a track and you have to notice. The connection drops in a lift and you have to decide
whether to wait or give up. A radio station announces the song that just started and you have to parse
it out of the stream. The listener takes a call, unplugs their headphones, locks the screen, or drops
onto cellular and expects the bitrate to follow. Written by hand, that is a few hundred lines of
callbacks and flags per app, and it is where the bugs live.

SwiftAudioKit is that layer. You give it a queue of tracks and it handles the rest: retrying failed
loads, waiting out a lost connection and picking up where it stopped, stepping quality down when a
stream keeps stalling and back up when it settles, reading titles and cover art off the stream, keeping
the lock screen and Control Center current, and pausing and resuming around interruptions.

Playback state is published rather than delivered through a delegate, so a SwiftUI view reads `state`,
`progress`, `metadata` and `upNext` directly and stays current with no mirroring layer. Underneath, the
decisions are made by a synchronous state machine that is tested on its own — which is why recovery
behaves the same way every time instead of depending on how `AVPlayer` happened to interleave its
callbacks.

## Features

- **Observable, main-actor player.** Bind SwiftUI views straight to the player; no mirroring layer.
- **Swift 6 strict concurrency.** The package builds in Swift 6 language mode. Every model
  (`AudioItem`, `AudioMetadata`, `PlaybackState`, `PlaybackProgress`, `AudioPlayerEvent`,
  `NetworkStatus`, `AudioPlayerError`) is a `Sendable` value type.
- **No dependencies.** Apple SDKs only.
- **Six platforms.** iOS, macOS, tvOS, watchOS, visionOS and Mac Catalyst are each built and tested in CI.
- **Typed event stream.** `AsyncStream<AudioPlayerEvent>` instead of a delegate protocol. Each caller
  gets its own stream, so several observers can listen at once.
- **Queue with repeat, shuffle and skipping.** Append, insert-next, reorder, jump, and exclude individual
  tracks from advancement without removing them.
- **Automatic recovery.** Failed loads are retried under a `RetryPolicy`; a lost connection parks the
  player in `.waitingForConnection` and resumes when the path returns, up to `maximumConnectionLossTime`.
- **Quality adaptation.** An item can carry a URL per `AudioQuality`. The player downgrades after
  repeated stalls, retries the higher bitrate on an interval, and falls back to the nearest available
  quality when an exact match is missing.
- **Real-time audio processing.** Hand the player any `AVAudioUnit` chain — an equalizer, a reverb,
  a compressor, your own AUv3 — and the stream is rendered through it, live streams included.
- **Now Playing and remote commands.** Lock screen, Control Center and the media keys, including remote
  cover art fetched from a URL and cached.
- **Interruption and route handling.** Calls, other apps and unplugged headphones pause with a
  `PauseReason`, and playback resumes afterwards when it should.
- **Configurable logging** through the unified log, off a single switch.

## Requirements

| | |
|---|---|
| Swift | 6.3 toolchain, Swift 6 language mode |
| iOS / tvOS / Mac Catalyst | 18.0+ |
| macOS | 15.0+ |
| watchOS | 11.0+ |
| visionOS | 2.0+ |

## Installation

SwiftAudioKit is distributed through Swift Package Manager.

### Xcode

1. **File > Add Package Dependencies…**
2. Enter `https://github.com/dioKaratzas/swift-audio-kit`
3. Choose the version rule and add **SwiftAudioKit** to your target.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/dioKaratzas/swift-audio-kit", from: "2.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SwiftAudioKit", package: "swift-audio-kit")
        ]
    )
]
```

## Quick start

```swift
import SwiftAudioKit

let player = AudioPlayer()
player.play(AudioItem(url: episodeURL, metadata: AudioMetadata(title: "Episode 1")))
```

`play(_:)` also takes an array, which becomes the queue:

```swift
player.play(episodes, startingAt: 3)
```

For background playback on iOS, add the `audio` value to your app's **Background Modes** capability. To
find out up front whether the audio session is available — rather than discovering it as silence —
activate it yourself:

```swift
do {
    try await player.prepareForPlayback()
} catch {
    // AudioPlayerError, e.g. .audioSessionFailed
}
```

## SwiftUI

The player publishes its own state, so a view reads it directly — no view model, no delegate, nothing to
keep in sync.

```swift
import SwiftAudioKit
import SwiftUI

struct PlayerView: View {
    let episodes: [AudioItem]

    @State private var player = AudioPlayer()

    var body: some View {
        VStack(spacing: 16) {
            Text(player.metadata.title ?? "Nothing playing")

            if let fraction = player.progress.fraction {
                ProgressView(value: fraction)
            }

            Button(player.state.isPlaying ? "Pause" : "Play") {
                player.togglePlayPause()
            }
            .disabled(player.currentItem == nil)
        }
        .onAppear { player.play(episodes) }
    }
}
```

Every property the view touches — `state`, `metadata`, `progress`, `quality`, `network`, `upNext` —
updates the view when it changes. `repeatMode`, `isShuffled`, `volume` and `rate` are settable, so
`@Bindable` gives you bindings for pickers, toggles and sliders.

### Seeking

Seeks are `async` and report whether they landed. By default the target is clamped to the seekable range,
which matters for live streams that only keep a window.

```swift
await player.seek(to: .seconds(90))
await player.seek(by: .seconds(-15))
await player.seekToLiveEdge()
await player.seekToStart()
```

`player.progress` carries `elapsed`, `duration`, `buffered`, `seekable`, plus `fraction`, `remaining`,
`bufferedAhead` and `isLive`. `duration` and `fraction` are `nil` for a live stream, which is the signal
to draw a LIVE badge instead of a scrubber.

## Queue

```swift
player.append(moreTracks)          // to the end; items already queued are ignored, matched by id
player.insertNext(track)           // right after the current track
player.play(track.id)              // jump to a queued track and play it
player.move(from: 4, to: 0)
player.remove(track.id)
player.removeAll()

player.repeatMode = .all           // .off, .one, .all
player.isShuffled = true
player.skippedItems.insert(track.id)   // stepped over when advancing, still in the queue
```

`move(from:to:)` takes the destination index with the item already lifted out, which is one less than
SwiftUI's `onMove` offset when moving a track later in the list.

Read back with `player.items`, `player.upNext`, `player.currentIndex`, `player.currentItem`,
`player.hasNext` and `player.hasPrevious`. `hasNext` and `hasPrevious` account for the repeat mode,
the shuffle order and the skipped set, so they are safe to disable buttons with.

## Configuration

`AudioPlayerConfiguration` bundles the policies. It is a `Hashable` value type and can be replaced on a
live player through `player.configuration`; every field, including `audioSession`, takes effect
immediately.

```swift
let player = AudioPlayer(
    configuration: AudioPlayerConfiguration(
        defaultQuality: .high,
        quality: .automatic(interval: .seconds(300), downgradeAfterInterruptions: 3),
        retry: RetryPolicy(maximumAttempts: 5, timeout: .seconds(5)),
        buffering: BufferingPolicy(
            preferredForwardDuration: .seconds(30),
            preferredPeakBitRate: 256_000,
            preferredPeakBitRateOnExpensiveNetworks: 64_000
        ),
        maximumConnectionLossTime: .seconds(60),
        resumesAfterInterruption: true,
        progressUpdateInterval: .milliseconds(500),
        audioSession: .managed,
        publishesNowPlayingInfo: true
    ),
    remoteCommands: .default
)
```

Presets cover the two common shapes:

```swift
AudioPlayerConfiguration.default
AudioPlayerConfiguration.podcast     // fixed quality, 120s forward buffer
AudioPlayerConfiguration.liveRadio   // fixed quality, unlimited retries, 10s forward buffer
```

`audioSession` decides how much of `AVAudioSession` the player owns: `.managed` configures and activates
it, `.mixing` does the same but mixes with other audio, and `.unmanaged` leaves the session entirely to
your app.

## Events

State lives on the player. Point-in-time notifications — a track finishing, the queue running out, an
error that was recovered from — arrive on `player.events`. Every call to `events` returns a fresh stream.

```swift
let observer = Task {
    for await event in player.events {
        switch event {
        case let .itemChanged(_, to):
            analytics.record(to?.displayTitle)
        case let .durationResolved(duration, itemID):
            cache.store(duration, for: itemID)
        case .queueExhausted:
            suggestSomethingElse()
        case let .failed(error):
            report(error)
        default:
            break
        }
    }
}
```

The full set is `stateChanged`, `itemChanged`, `itemFinished`, `queueExhausted`, `durationResolved`,
`metadataUpdated`, `qualityChanged`, `networkChanged`, `interrupted`, `interruptionEnded`,
`recoverableErrorLogged` and `failed`.

## Quality and multi-bitrate sources

An `AudioItem` can point at one URL per `AudioQuality`:

```swift
let mainMix = AudioItem(
    sources: AudioSources([
        .low: URL(string: "https://stream.example.com/mp3-128")!,
        .medium: URL(string: "https://stream.example.com/mp3-192")!,
        .high: URL(string: "https://stream.example.com/aac-320")!
    ])!,
    metadata: AudioMetadata(title: "Main Mix")
)

player.setQuality(.medium)
```

With `QualityPolicy.automatic`, repeated stalls drop the quality a step and the player tries to climb back
on the configured interval; changing quality reloads the stream and returns to the same position.
`AudioSources.resolve(preferring:)` picks the nearest available quality, preferring a lower one over a
higher one, so an item that only publishes `.high` still plays when the player asks for `.medium`.
Inspect the options with `sources.availableQualities`, `sources.highest` and `sources.lowest`.

`BufferingPolicy.preferredPeakBitRateOnExpensiveNetworks` is applied when `player.network`
reports `prefersReducedData` — a metered cellular link or Low Data Mode.

## Now Playing and remote commands

Pass the commands you want to handle; the player wires them to its own transport.

```swift
let player = AudioPlayer(remoteCommands: .default)
// .default   = .transport + .changePlaybackPosition
// .transport = play, pause, togglePlayPause, nextTrack, previousTrack
// or an explicit set: [.play, .pause, .stop, .skipForward, .skipBackward]
```

While `configuration.publishesNowPlayingInfo` is true, `MPNowPlayingInfoCenter` is kept in step with the
current item, metadata, elapsed time, duration and playback rate, and live streams are flagged as such.
Artwork comes from `AudioMetadata.artwork`, which is either embedded data or a URL:

```swift
AudioMetadata(title: "Episode 1", artwork: .url(coverURL))
AudioMetadata(title: "Episode 1", artwork: .data(pngData))
Artwork(image: coverImage)   // UIImage on UIKit platforms, NSImage on AppKit
```

Remote artwork is fetched once per URL and cached, then the Now Playing entry is rewritten. Metadata
you supply on the item outranks metadata the stream sends, so a station can keep one fixed cover while
another follows the track. Call `player.refreshNowPlayingInfo()` to republish on demand.

## Stream metadata

Streams that carry timed metadata are parsed by `DefaultMetadataParser`, which maps the common keys and
reads the cover art URL that Shoutcast stations send. Replace it to handle a station's own conventions:

```swift
struct RadioMetadataParser: MetadataParser {
    private let base = DefaultMetadataParser()

    func metadata(from entries: [MetadataEntry]) -> AudioMetadata {
        var metadata = base.metadata(from: entries)
        // e.g. split "Artist - Title" out of the single title field
        return metadata
    }
}

player.metadataParser = RadioMetadataParser()
```

## Audio processing

`AVPlayer` streams; `AVAudioEngine` processes. Neither does the other well, so the player runs both:
audio is pulled out of the item, rendered through an `AVAudioEngine` graph of your audio units, and put
back. Assign the chain and keep your own reference to whatever you want to control:

```swift
let equalizer = AVAudioUnitEQ(numberOfBands: 10)
let reverb = AVAudioUnitReverb()
player.audioProcessing.units = [equalizer, reverb]
```

Units are connected first to last. Their parameters are safe to set while audio renders and take effect
immediately, with no reload and no gap:

```swift
equalizer.bands[0].frequency = 60
equalizer.bands[0].gain = 6
equalizer.bypass = false
```

Anything `AVAudioEngine` can host works — `AVAudioUnitEQ`, `AVAudioUnitReverb`, `AVAudioUnitDelay`,
`AVAudioUnitDistortion`, and any Audio Unit you load yourself with
`AVAudioUnit.instantiate(with:options:)`.

Two limits, both enforced rather than left to discover:

- An `AVAudioUnitTimeEffect` — `AVAudioUnitTimePitch` and `AVAudioUnitVarispeed` — is dropped from the
  chain and logged. Every block the player hands over has to come back the same length, and a time
  effect by definition returns a different one. Use `player.rate` to change speed.
- Not every stream can be processed. A local file and a progressive download always can. A live stream
  and an HLS playlist expose no audio track, and can only be processed on systems that can tap the mix
  of all audio tracks instead. `player.audioProcessing.isAvailable` reports what the item playing can
  do, so read it before offering the controls.

Replacing `units` rebuilds the render graph, so a new chain takes effect on the next item. Reach for a
unit's own `bypass` to switch an effect off in place. There is no audio processing on watchOS, where
neither the audio units nor the underlying framework exist.

## Logging

Everything the package logs goes to the unified log under the `com.swiftaudiokit` subsystem, in the
categories `player`, `engine`, `session`, `network` and `nowPlaying`. One switch controls it:

```swift
AudioPlayerLog.level = .notice   // .debug, .info, .notice, .error, .off
```

Messages below the level are never even built. The default is `.debug`, because the unified log already
keeps debug messages out of the persisted store. Follow it with:

```sh
log stream --predicate 'subsystem == "com.swiftaudiokit"'
```

### A note on console noise

While a debugger is attached, AVFoundation prints its own internal diagnostics to the Xcode console —
lines such as `signalled err=…`, `ICY PUMP`, and messages from `FigStreamPlayer`. They come from
AVFoundation, not from this package.

These lines were measured: they never reach stderr and never reach the unified log. They are visible only
in Xcode with a debugger attached, and your users never see them. They are not errors your app needs to
handle, and they are not a sign that playback failed — real failures arrive as `AudioPlayerError` on the
state and on the event stream. SwiftAudioKit emits nothing outside its own `com.swiftaudiokit` subsystem.

## Documentation

Full API reference: **[diokaratzas.github.io/swift-audio-kit](https://diokaratzas.github.io/swift-audio-kit/documentation/swiftaudiokit/)**

Build it locally with `./Scripts/generate_docs.sh`.

## Example app

[`Examples/SwiftAudioKitExample`](Examples/SwiftAudioKitExample) is a multiplatform SwiftUI app that
exercises the whole surface: queue editing, per-track skipping, live scrubbing, quality switching,
network and state badges, a ten-band equalizer with named presets, a custom metadata parser, and a
live event log. It plays real multi-bitrate
radio streams, so quality changes and stream metadata are visible as they happen.

## Contributing

Pull requests are welcome.

1. Fork the repository and branch off `master`.
2. Make your change, and add tests — the state machine is covered by synchronous unit tests, so most
   behaviour can be tested without touching `AVPlayer`.
3. Run `swift test` and `./Scripts/swiftformat.sh lint-changed`. CI runs the tests on all six
   platforms and checks formatting.
4. Open a pull request describing the behaviour that changed.

## License

Apache License 2.0. See [LICENSE](LICENSE).
