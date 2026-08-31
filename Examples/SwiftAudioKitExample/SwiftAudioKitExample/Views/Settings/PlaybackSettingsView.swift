//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI
import SwiftAudioKit

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

                Section {
                    LabeledContent("Volume") {
                        HStack {
                            Image(systemName: "speaker.fill")
                            Slider(value: $player.volume, in: 0 ... 1)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 220)
                    }

                    LabeledContent {
                        HStack {
                            Slider(value: $player.rate, in: 0.5 ... 2, step: 0.25)
                            Text(String(format: "%.2f×", player.rate))
                                .font(.caption.monospacedDigit())
                                .frame(width: 48, alignment: .trailing)
                        }
                        .frame(minWidth: 220)
                    } label: {
                        Text("Rate")
                    }
                } header: {
                    Text("Output")
                } footer: {
                    Text("Rate applies to on-demand tracks. A live stream always plays at 1×.")
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
                    LabeledContent("Source", value: player.progress.isLive ? "Live stream" : "On demand")
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
