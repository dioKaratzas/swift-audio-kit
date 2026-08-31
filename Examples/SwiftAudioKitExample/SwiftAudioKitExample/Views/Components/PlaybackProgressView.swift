//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI
import SwiftAudioKit

struct PlaybackProgressView: View {
    let player: AudioPlayer

    @State private var scrubbing: Double?

    var body: some View {
        VStack(spacing: 4) {
            if let fraction = player.progress.fraction {
                Slider(value: binding(for: fraction), in: 0 ... 1) { editing in
                    guard !editing, let target else {
                        return
                    }
                    Task {
                        await player.seek(to: target)
                        scrubbing = nil
                    }
                }
            } else {
                liveIndicator
            }

            HStack {
                Text(player.progress.elapsed.formattedTime)
                Spacer()
                if let remaining = player.progress.remaining {
                    Text("-\(remaining.formattedTime)")
                } else if let ahead = player.progress.bufferedAhead {
                    Text("buffered \(ahead.formattedTime)")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var liveIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)
            Text("LIVE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.red)
            Spacer()
        }
    }

    private var target: Duration? {
        guard let scrubbing, let duration = player.progress.duration else {
            return nil
        }
        return duration * scrubbing
    }

    private func binding(for fraction: Double) -> Binding<Double> {
        Binding(
            get: { scrubbing ?? fraction },
            set: { scrubbing = $0 }
        )
    }
}
