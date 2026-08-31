//
//  SwiftAudioKitExample
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftAudioKit
import SwiftUI

struct StateBadge: View {
    let state: PlaybackState

    var body: some View {
        Label(state.label, systemImage: symbol)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.15), in: .capsule)
            .foregroundStyle(tint)
    }

    private var symbol: String {
        switch state {
        case .idle: "stop.circle"
        case .loading, .buffering: "arrow.triangle.2.circlepath"
        case .playing: "waveform"
        case .paused: "pause.circle"
        case .waitingForConnection: "wifi.exclamationmark"
        case .failed: "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch state {
        case .playing: .green
        case .failed: .red
        case .waitingForConnection: .orange
        case .idle, .loading, .buffering, .paused: .secondary
        }
    }
}

struct NetworkBadge: View {
    let status: NetworkStatus

    var body: some View {
        Label {
            Text(status.label)
        } icon: {
            Image(systemName: status.symbol)
        }
        .font(.caption)
        .foregroundStyle(status.isUsable ? .secondary : Color.orange)
    }
}

struct QualityBadge: View {
    let quality: AudioQuality

    var body: some View {
        Text(quality.label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: .capsule)
    }
}
