# ``SwiftAudioKit``

Queue-driven audio playback built on `AVPlayer`.

## Overview

``AudioPlayer`` owns a queue of ``AudioItem`` values and drives `AVPlayer` on your
behalf. It resolves the right stream for the current ``AudioQuality``, retries
failed loads, waits out connection losses, reacts to audio session interruptions,
and keeps the system Now Playing info and remote commands in sync.

The player is `@MainActor` and `@Observable`. Reading ``AudioPlayer/state``,
``AudioPlayer/progress``, ``AudioPlayer/metadata``, ``AudioPlayer/quality``,
``AudioPlayer/network`` or ``AudioPlayer/upNext`` from a SwiftUI view is enough to
keep that view current; there is no delegate to implement. Point-in-time
notifications that are not part of the current state — a track finishing, the
queue running out, a recovered error — arrive as ``AudioPlayerEvent`` values on
the ``AudioPlayer/events`` stream.

```swift
let player = AudioPlayer()
player.play([
    AudioItem(url: episodeURL, metadata: AudioMetadata(title: "Episode 1"))
])
```

Behaviour is set through ``AudioPlayerConfiguration``, which bundles the retry,
buffering, quality and audio session policies. ``AudioPlayerConfiguration/podcast``
and ``AudioPlayerConfiguration/liveRadio`` are presets for the two common shapes.

The package has no dependencies outside the Apple SDKs.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Concurrency>
- ``AudioPlayer``

### Playing

- ``AudioItem``
- ``AudioSources``
- ``AudioQuality``
- ``PlaybackProgress``

### Queue

- ``PlaybackQueue``
- ``PlaybackMode``
- ``RepeatMode``

### Configuration

- ``AudioPlayerConfiguration``
- ``QualityPolicy``
- ``RetryPolicy``
- ``BufferingPolicy``
- ``AudioSessionPolicy``

### State

- ``PlaybackState``
- ``PauseReason``
- ``PlaybackIntent``
- ``AudioPlayerEvent``
- ``NetworkStatus``

### Metadata

- ``AudioMetadata``
- ``Artwork``
- ``PlatformImage``
- ``MetadataParser``
- ``DefaultMetadataParser``
- ``MetadataEntry``

### Now Playing

- ``RemoteCommand``

### Diagnostics

- ``AudioPlayerLog``
- ``AudioPlayerError``
- ``PlaybackFailure``
