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
            ViewThatFits(in: .horizontal) {
                wideLayout
                narrowLayout
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(backdrop)
            .navigationTitle("Now Playing")
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 32) {
            ArtworkView(artwork: player.metadata.artwork)
                .frame(width: 260, height: 260)

            VStack(alignment: .leading, spacing: 20) {
                titles(alignment: .leading)
                PlaybackProgressView(player: player)
                if showsTransport {
                    TransportControls(player: player)
                    SeekControls(player: player)
                }
                badges(alignment: .leading)
                failureBanner
                Spacer(minLength: 0)
            }
            .frame(minWidth: 260, maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: 760)
    }

    private var narrowLayout: some View {
        ScrollView {
            VStack(spacing: 22) {
                ArtworkView(artwork: player.metadata.artwork)
                    .frame(maxWidth: 280)
                titles(alignment: .center)
                PlaybackProgressView(player: player)
                if showsTransport {
                    TransportControls(player: player)
                    SeekControls(player: player)
                }
                badges(alignment: .center)
                failureBanner
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
    }

    private func titles(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(player.metadata.title ?? player.currentItem.map(Catalog.station) ?? "Nothing playing")
                .font(.title2.weight(.semibold))
                .lineLimit(2)

            if let artist = player.metadata.artist {
                Text(artist)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let item = player.currentItem {
                Text(Catalog.station(for: item))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .animation(.default, value: player.metadata)
    }

    private func badges(alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 10) {
            StateBadge(state: player.state)
            QualityBadge(quality: player.quality)
            NetworkBadge(status: player.network)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
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
