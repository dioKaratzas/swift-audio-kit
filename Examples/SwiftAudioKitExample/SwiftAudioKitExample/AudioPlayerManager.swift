import SwiftUI
import Combine
import AVFoundation
import SwiftAudioKit

class AudioPlayerManager: ObservableObject {
    @Published
    var currentTrackTitle: String = "No Track"
    @Published
    var isPlaying: Bool = false

    private var audioPlayer: AudioPlayer

    init() {
        audioPlayer = try! AudioPlayer(nowPlayableService: .init(
            allowsExternalPlayback: true,
            commands: [.play, .pause, .previousTrack, .nextTrack]
        ))
        setupPlayer()
    }

    private func setupPlayer() {
        audioPlayer.delegate = self
        loadPlaylist()
        playCurrentItem()
    }

    private func loadPlaylist() {
        // Load your playlist here
        audioPlayer.add(items: [
            AudioItem(soundURLs: [.high: URL(string: "http://radio.1055rock.gr:30000/1055")!])!,
            AudioItem(soundURLs: [.high: URL(string: "https://cast.magicstreams.gr:2200/ssl/psyndora?mp=/stream")!])!
        ])
    }

    private func playCurrentItem() {
        audioPlayer.resume()
        isPlaying = true
    }

    func play() {
        playCurrentItem()
    }

    func pause() {
        audioPlayer.pause()
        isPlaying = false
    }

    func nextTrack() {
        guard audioPlayer.hasNext else {
            return
        }
        audioPlayer.next()
    }

    func previousTrack() {
        guard audioPlayer.hasPrevious else {
            return
        }
        audioPlayer.previous()
    }
}

extension AudioPlayerManager: AudioPlayerDelegate {
    func audioPlayer(_ audioPlayer: AudioPlayer, didChangeStateFrom from: AudioPlayerState, to state: AudioPlayerState) {
        if state.isPlaying {
            isPlaying = true
        } else {
            isPlaying = false
        }
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, willStartPlaying item: AudioItem) {
        currentTrackTitle = item.title ?? "Unknown Track"
    }

    func audioPlayer(_ audioPlayer: AudioPlayer, didUpdateEmptyMetadataOn item: AudioItem, withData data: Metadata) {
        currentTrackTitle = item.title ?? "Unknown Track"
    }

    // Implement other delegate methods as needed
}
