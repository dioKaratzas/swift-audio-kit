//
//  SwiftAudioKitExample
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation
import SwiftAudioKit

/// Owns the player and the app-level state around it. The player publishes its own state,
/// so nothing here mirrors it.
@Observable
@MainActor
final class PlayerModel {
    let player: AudioPlayer
    let log = EventLog()

    private(set) var sessionError: AudioPlayerError?
    private var eventTask: Task<Void, Never>?

    init() {
        player = AudioPlayer(
            configuration: AudioPlayerConfiguration(
                quality: .automatic(interval: .seconds(60), downgradeAfterInterruptions: 2),
                retry: RetryPolicy(maximumAttempts: 5, timeout: .seconds(5)),
                buffering: BufferingPolicy(
                    preferredForwardDuration: .seconds(30),
                    preferredPeakBitRate: 256_000,
                    preferredPeakBitRateOnExpensiveNetworks: 64000
                ),
                progressUpdateInterval: .milliseconds(500)
            ),
            remoteCommands: .default
        )

        observeEvents()
    }

    isolated deinit {
        eventTask?.cancel()
    }

    func start() async {
        do {
            try await player.prepareForPlayback()
            sessionError = nil
        } catch {
            sessionError = error
        }
        player.play(Catalog.all)
    }

    func toggleSkipped(_ item: AudioItem) {
        if player.skippedItems.contains(item.id) {
            player.skippedItems.remove(item.id)
        } else {
            player.skippedItems.insert(item.id)
        }
    }

    func isSkipped(_ item: AudioItem) -> Bool {
        player.skippedItems.contains(item.id)
    }

    private func observeEvents() {
        eventTask = Task { [player, log] in
            for await event in player.events {
                log.record(event)
            }
        }
    }
}
