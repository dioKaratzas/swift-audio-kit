//
//  SwiftAudioKitExample
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftAudioKit
import SwiftUI

struct PlaybackSettingsView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        @Bindable var player = model.player

        NavigationStack {
            Form {
                Section("Order") {
                    Picker("Repeat", selection: $player.repeatMode) {
                        Text("Off").tag(RepeatMode.off)
                        Text("One").tag(RepeatMode.one)
                        Text("All").tag(RepeatMode.all)
                    }
                    Toggle("Shuffle", isOn: $player.isShuffled)
                }

                Section("Output") {
                    LabeledContent("Volume") {
                        Slider(value: $player.volume, in: 0 ... 1)
                            .frame(width: 160)
                    }
                    LabeledContent("Rate") {
                        Slider(value: $player.rate, in: 0.5 ... 2, step: 0.25)
                            .frame(width: 160)
                    }
                    Text(String(format: "%.2f×", player.rate))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Quality", selection: qualityBinding) {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            Text(quality.label).tag(quality)
                        }
                    }
                } header: {
                    Text("Quality")
                } footer: {
                    Text("Chosen quality is a preference. The nearest available stream is used, "
                        + "and metered connections drop to the reduced bitrate.")
                }

                Section("Current") {
                    LabeledContent("State", value: player.state.label)
                    LabeledContent("Network", value: player.network.label)
                    LabeledContent("Metered", value: player.network.prefersReducedData ? "Yes" : "No")
                    if let duration = player.progress.duration {
                        LabeledContent("Duration", value: duration.formattedTime)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var qualityBinding: Binding<AudioQuality> {
        Binding(
            get: { model.player.quality },
            set: { model.player.setQuality($0) }
        )
    }
}
