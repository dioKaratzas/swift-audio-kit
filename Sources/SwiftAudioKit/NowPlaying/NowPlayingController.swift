//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import MediaPlayer

/// Owns everything MediaPlayer, which carries no concurrency annotations of its own.
@MainActor
final class NowPlayingController {
    private let session: NowPlayingSession
    private var tokens = [RemoteCommand: Any]()
    private let skipInterval = Duration.seconds(15)
    private var artworkURL: URL?
    private var loadedArtwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?
    private var lastUpdate: (item: AudioItem, metadata: AudioMetadata, progress: PlaybackProgress, isPlaying: Bool)?

    init(session: NowPlayingSession) {
        self.session = session
    }

    isolated deinit {
        unregisterAll()
    }

    func register(_ commands: Set<RemoteCommand>, handler: @escaping @MainActor (RemoteCommand, Duration?) -> Void) {
        unregisterAll()

        for command in RemoteCommand.allCases {
            let remote = command.remoteCommand(in: session.commandCenter)
            guard commands.contains(command) else {
                remote.isEnabled = false
                continue
            }

            remote.isEnabled = true
            configureInterval(on: remote, for: command)
            // The handler must answer synchronously, so it accepts the command and defers the work.
            tokens[command] = remote.addTarget { event in
                let position = (event as? MPChangePlaybackPositionCommandEvent)
                    .map { Duration.seconds($0.positionTime) }
                MainActor.assumeIsolated { handler(command, position) }
                return .success
            }
        }
    }

    func unregisterAll() {
        for (command, token) in tokens {
            command.remoteCommand(in: session.commandCenter).removeTarget(token)
        }
        tokens.removeAll()
    }

    func update(item: AudioItem?, metadata: AudioMetadata, progress: PlaybackProgress, isPlaying: Bool) {
        guard let item else {
            clear()
            return
        }
        lastUpdate = (item, metadata, progress, isPlaying)

        var info: [String: Any] = [
            MPNowPlayingInfoPropertyAssetURL: item.sources.highest.url,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: progress.isLive,
            MPMediaItemPropertyTitle: metadata.title ?? item.displayTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress.elapsed.totalSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        info[MPMediaItemPropertyArtist] = metadata.artist
        info[MPMediaItemPropertyAlbumTitle] = metadata.album
        info[MPMediaItemPropertyAlbumTrackNumber] = metadata.trackNumber
        info[MPMediaItemPropertyAlbumTrackCount] = metadata.trackCount
        info[MPMediaItemPropertyPlaybackDuration] = progress.duration?.totalSeconds
        info[MPMediaItemPropertyArtwork] = artwork(for: metadata.artwork)

        session.infoCenter.nowPlayingInfo = info
        setPlaybackState(isPlaying: isPlaying)
        session.becomeActive()
    }

    func clear() {
        lastUpdate = nil
        artworkTask?.cancel()
        artworkURL = nil
        loadedArtwork = nil
        session.infoCenter.nowPlayingInfo = nil
        setPlaybackState(isPlaying: false)
    }

    /// Remote artwork is fetched once per URL and cached, because now playing information is
    /// rewritten on every playhead tick.
    private func artwork(for artwork: Artwork?) -> MPMediaItemArtwork? {
        switch artwork {
        case let .data(data):
            return MPMediaItemArtwork(data: data)
        case let .url(url):
            guard url != artworkURL else {
                return loadedArtwork
            }
            load(url)
            return nil
        case nil:
            artworkTask?.cancel()
            artworkURL = nil
            loadedArtwork = nil
            return nil
        }
    }

    private func load(_ url: URL) {
        artworkURL = url
        loadedArtwork = nil
        artworkTask?.cancel()

        artworkTask = Task { [weak self] in
            let data = try? await URLSession.shared.data(from: url).0
            guard let self, !Task.isCancelled, artworkURL == url,
                  let artwork = data.flatMap(MPMediaItemArtwork.init(data:)) else {
                return
            }
            loadedArtwork = artwork
            republish()
        }
    }

    private func republish() {
        guard let lastUpdate else {
            return
        }
        update(
            item: lastUpdate.item,
            metadata: lastUpdate.metadata,
            progress: lastUpdate.progress,
            isPlaying: lastUpdate.isPlaying
        )
    }

    private func setPlaybackState(isPlaying: Bool) {
        #if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
            session.infoCenter.playbackState = isPlaying ? .playing : .paused
        #endif
    }

    private func configureInterval(on remote: MPRemoteCommand, for command: RemoteCommand) {
        guard let skip = remote as? MPSkipIntervalCommand else {
            return
        }
        skip.preferredIntervals = [NSNumber(value: skipInterval.totalSeconds)]
    }
}

private extension RemoteCommand {
    func remoteCommand(in center: MPRemoteCommandCenter) -> MPRemoteCommand {
        switch self {
        case .play: center.playCommand
        case .pause: center.pauseCommand
        case .togglePlayPause: center.togglePlayPauseCommand
        case .stop: center.stopCommand
        case .nextTrack: center.nextTrackCommand
        case .previousTrack: center.previousTrackCommand
        case .skipForward: center.skipForwardCommand
        case .skipBackward: center.skipBackwardCommand
        case .changePlaybackPosition: center.changePlaybackPositionCommand
        }
    }
}

private extension MPMediaItemArtwork {
    convenience init?(data: Data) {
        guard let image = PlatformImage(data: data) else {
            return nil
        }
        self.init(boundsSize: image.size) { _ in image }
    }
}
