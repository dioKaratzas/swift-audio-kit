//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI
import SwiftAudioKit

struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var model

    private var player: AudioPlayer {
        model.player
    }

    /// The Mac keeps its transport in the window's bottom bar, so it is not repeated here.
    private var showsTransport: Bool {
        #if os(macOS)
            false
        #else
            true
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ArtworkView(artwork: player.metadata.artwork)
                        .frame(maxWidth: 300)
                        .padding(.top, 8)

                    titles
                    PlaybackProgressView(player: player)

                    if showsTransport {
                        TransportControls(player: player)
                        SeekControls(player: player)
                    }

                    badges
                    failureBanner
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Now Playing")
            .background(backdrop)
        }
    }

    private var titles: some View {
        VStack(spacing: 6) {
            Text(player.metadata.title ?? player.currentItem.map(Catalog.station) ?? "Nothing playing")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            if let artist = player.metadata.artist {
                Text(artist)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let item = player.currentItem {
                Text(Catalog.station(for: item))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
            }
        }
        .animation(.default, value: player.metadata)
    }

    private var badges: some View {
        HStack(spacing: 10) {
            StateBadge(state: player.state)
            QualityBadge(quality: player.quality)
            NetworkBadge(status: player.network)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var failureBanner: some View {
        if let error = player.state.error {
            banner(error.errorDescription ?? "Playback failed", symbol: "exclamationmark.triangle.fill", tint: .red)
        } else if let error = model.sessionError {
            banner(error.errorDescription ?? "Audio session unavailable", symbol: "speaker.slash", tint: .orange)
        }
    }

    private func banner(_ message: String, symbol: String, tint: Color) -> some View {
        Label(message, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [.accentColor.opacity(0.12), .clear],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }
}
