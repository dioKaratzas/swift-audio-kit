# Processing audio

Render playback through audio units of your own.

## Overview

`AVPlayer` is good at streaming and poor at processing. `AVAudioEngine` is the
reverse: it hosts audio units happily but has no answer for a network stream, an
HLS playlist, or a radio station that never ends. The player runs both. Audio is
pulled out of the item as it plays, rendered through an `AVAudioEngine` graph
built from your units, and put back before it reaches the output.

Assign the chain through ``AudioPlayer/audioProcessing`` and keep your own
reference to whatever you want to control:

```swift
let equalizer = AVAudioUnitEQ(numberOfBands: 10)
let reverb = AVAudioUnitReverb()
player.audioProcessing.units = [equalizer, reverb]
```

Units are connected first to last, so that chain equalizes and then reverberates.

## Changing an effect while it plays

An audio unit's parameters are safe to set from another thread and take effect on
the next block, so a slider bound straight to a unit is heard as it moves — no
reload, no gap, nothing to schedule:

```swift
equalizer.bands[0].frequency = 60
equalizer.bands[0].gain = 6
equalizer.bypass = false
```

Replacing ``AudioProcessing/units`` is the one change that is not immediate. A
different chain is a different render graph, and rebuilding one underneath a
running stream is not safe, so a new chain takes effect on the next item. To turn
an effect off in place, use that unit's own `bypass`.

## Building a graphic equalizer

`AVAudioUnitEQ` is the whole equalizer. Configure its bands once and write to
their gains afterwards:

```swift
let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
let equalizer = AVAudioUnitEQ(numberOfBands: frequencies.count)

for (band, frequency) in zip(equalizer.bands, frequencies) {
    band.filterType = .parametric
    band.frequency = frequency
    band.bandwidth = 1
    band.bypass = false
}

player.audioProcessing.units = [equalizer]
equalizer.bands[0].gain = 6      // heard immediately
equalizer.globalGain = -3        // preamp, to make up a heavy cut
```

## What can be processed

Not every stream exposes something to attach a processor to. A local file and a
progressive download always do. A live stream and an HLS playlist expose no audio
track, and can only be processed on systems that can tap the mix of all audio
tracks instead.

``AudioProcessing/isAvailable`` reports what the item currently playing can do. It
resolves when an item loads, so read it once playback has started rather than at
launch:

```swift
if player.audioProcessing.isAvailable {
    EqualizerControls(equalizer: equalizer)
} else {
    Text("This stream cannot be equalized.")
}
```

## What cannot go in the chain

An `AVAudioUnitTimeEffect` — `AVAudioUnitTimePitch` and `AVAudioUnitVarispeed` —
is dropped from the chain and logged as an error. Every block the player hands
over has to come back the same length, and a time effect by definition returns a
different one. The rest of the chain is kept. Use ``AudioPlayer/rate`` to change
playback speed.

Everything else `AVAudioEngine` can host works, including any Audio Unit you load
yourself:

```swift
let component = AudioComponentDescription(...)
let unit = try await AVAudioUnit.instantiate(with: component, options: [])
player.audioProcessing.units = [unit]
```

## Platforms

There is no audio processing on watchOS, which has neither the audio units nor the
framework the underlying tap lives in. ``AudioPlayer/audioProcessing`` does not
exist there, so guard any code that touches it:

```swift
#if !os(watchOS)
    player.audioProcessing.units = [equalizer]
#endif
```
