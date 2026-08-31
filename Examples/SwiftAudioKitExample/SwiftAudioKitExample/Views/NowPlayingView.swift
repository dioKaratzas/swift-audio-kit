//
//  SwiftAudioKitExample
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftAudioKit
import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var model

    private var player: AudioPlayer { model.player }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                header
                artwork
                titles
                PlaybackProgressView(player: player)
                TransportControls(player: player)
                SeekControls(player: player)
                Spacer()
                failureBanner
            }
            .padding()
            .navigationTitle("Now Playing")
        }
    }

    private var header: some View {
        HStack {
            StateBadge(state: player.state)
            Spacer()
            QualityBadge(quality: player.quality)
            NetworkBadge(status: player.network)
        }
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.quaternary)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 280)
    }

    private var titles: some View {
        VStack(spacing: 6) {
            Text(player.metadata.title ?? player.currentItem?.displayTitle ?? "Nothing playing")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            if let subtitle = player.metadata.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var failureBanner: some View {
        if let error = player.state.error {
            Label(error.errorDescription ?? "Playback failed", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.red.opacity(0.1), in: .rect(cornerRadius: 12))
        } else if let error = model.sessionError {
            Label(error.errorDescription ?? "Audio session unavailable", systemImage: "speaker.slash")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }
}
