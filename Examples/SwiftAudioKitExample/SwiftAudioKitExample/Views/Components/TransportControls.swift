//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI
import SwiftAudioKit

struct TransportControls: View {
    let player: AudioPlayer

    var body: some View {
        HStack(spacing: 36) {
            Button { player.previous() } label: {
                Image(systemName: "backward.fill")
            }
            .disabled(!player.hasPrevious)

            Button { player.togglePlayPause() } label: {
                Image(systemName: player.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            .disabled(player.currentItem == nil)
            .overlay {
                if player.state.isTransient {
                    ProgressView()
                }
            }

            Button { player.next() } label: {
                Image(systemName: "forward.fill")
            }
            .disabled(!player.hasNext)
        }
        .font(.title2)
        .buttonStyle(.plain)
    }
}

struct SeekControls: View {
    let player: AudioPlayer

    var body: some View {
        HStack(spacing: 24) {
            Button { Task { await player.seek(by: .seconds(-15)) } } label: {
                Label("Back 15", systemImage: "gobackward.15")
            }
            Button { Task { await player.seek(by: .seconds(15)) } } label: {
                Label("Forward 15", systemImage: "goforward.15")
            }
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .buttonStyle(.plain)
        .disabled(player.progress.isLive)
    }
}
