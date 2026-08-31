//
//  SwiftAudioKitExample
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftAudioKit
import SwiftUI

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
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var liveIndicator: some View {
        Label("Live", systemImage: "dot.radiowaves.left.and.right")
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
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
