
# SwiftAudioKit

[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager/)
![Platform iOS | tvOS | macOS | watchOS](https://img.shields.io/badge/platform-iOS%20|%20tvOS%20|%20macOS%20|%20watchOS-lightgrey.svg)
![Latest Version](https://img.shields.io/github/v/release/diokaratzas/swift-audio-kit)

**SwiftAudioKit** is a robust, feature-rich wrapper around `AVPlayer`, designed to simplify audio playback on iOS, tvOS, macOS and watchOS.

## Features

- **Quality Control:** Automatically adapts to interruptions (buffering) and adjusts playback based on delay.
- **Retry Mechanism:** Automatically retries playback if the player encounters an error.
- **Connection Handling:** Smart handling of connection interruptions and seamless recovery.
- **Audio Item Enqueuing:** Easily enqueue audio items for uninterrupted playback.
- **Playback Modes:** Supports repeat, repeat all, and shuffle modes.
- **MPNowPlayingInfoCenter Integration:** Full support for Control Center and lock screen media controls.
- **High Customizability:** Flexible and customizable to fit your specific needs.

## Installation
#### Xcode
SwiftAudioKit is vailable exclusively through Swift Package Manager (SPM). To integrate it into your project, follow these steps:

1. Open your project in Xcode.
2. Go to **File > Add Packages...**
3. Enter the following URL in the search field: `https://github.com/diokaratzas/swift-audio-kit`
4. Choose the version you want to install and click **Add Package**.

#### Or Swift Package

To use the SwiftAudioKit with your package, first add it as a dependency:

```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/diokaratzas/swift-audio-kit", from: "1.0.0"),
    ],
    targets: [
        // targets
    ]
)
```

## Usage

### Basic Usage

Here’s a quick example of how to get started with SwiftAudioKit:

```swift
let delegate: AudioPlayerDelegate = ...

let player = AudioPlayer()
player.delegate = delegate
let item = AudioItem(mediumQualitySoundURL: track.streamURL)
player.playItem(item)
```

### Delegate Methods

SwiftAudioKit uses delegation to notify about status changes and other events.

#### State Changes

This method is called when the player’s state changes:

```swift
func audioPlayer(_ audioPlayer: AudioPlayer, didChangeStateFrom from: AudioPlayerState, toState to: AudioPlayerState)
```

#### Duration & Progression

When the duration of the current item is found:

```swift
func audioPlayer(_ audioPlayer: AudioPlayer, didFindDuration duration: TimeInterval, forItem item: AudioItem)
```

This method is regularly called to update playback progression:

```swift
func audioPlayer(_ audioPlayer: AudioPlayer, didUpdateProgressionToTime time: TimeInterval, percentageRead: Float)
```

`percentageRead` is a `Float` value between 0 and 100, perfect for updating a `UISlider`.

#### Queue Management

This method is called when a new audio item starts playing:

```swift
func audioPlayer(_ audioPlayer: AudioPlayer, willStartPlayingItem item: AudioItem)
```

### Control Center & Lock Screen Integration

To handle media controls via the Control Center or lock screen:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    application.beginReceivingRemoteControlEvents()
    return true
}

// In your UIResponder (or AppDelegate):
override func remoteControlReceived(with event: UIEvent?) {
    if let event = event {
        yourPlayer.remoteControlReceived(with: event)
    }
}
```

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a new feature branch: `git checkout -b my-new-feature`.
3. Commit your changes: `git commit -am 'Add some feature'`.
4. Push to the branch: `git push origin my-new-feature`.
5. Submit a pull request.

## Todo

- Increase unit test coverage.
- Refactor the current state handling system.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.

---

### Acknowledgments

This project is based on the original [AudioPlayer](https://github.com/delannoyk/AudioPlayer) by [Kevin Delannoy](https://github.com/delannoyk). Special thanks to Kevin for his foundational work, which has been instrumental in the development of SwiftAudioKit.
