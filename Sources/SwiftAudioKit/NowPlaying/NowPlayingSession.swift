//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import MediaPlayer
import AVFoundation

/// Prefers the per-session centres over the process-wide singletons, and falls back to them
/// on watchOS and macOS, where `MPNowPlayingSession` does not exist.
@MainActor
final class NowPlayingSession {
    let infoCenter: MPNowPlayingInfoCenter
    let commandCenter: MPRemoteCommandCenter

    #if !os(watchOS) && !os(macOS)
        private let session: MPNowPlayingSession?
    #endif

    init(players: [AVPlayer]) {
        #if !os(watchOS) && !os(macOS)
            let session = MPNowPlayingSession(players: players)
            // Metadata is published deliberately, so the elapsed time never disagrees with the machine.
            session.automaticallyPublishesNowPlayingInfo = false
            self.session = session
            infoCenter = session.nowPlayingInfoCenter
            commandCenter = session.remoteCommandCenter
        #else
            infoCenter = .default()
            commandCenter = .shared()
        #endif
    }

    func becomeActive() {
        #if !os(watchOS) && !os(macOS)
            session?.becomeActiveIfPossible(completion: nil)
        #endif
    }
}
