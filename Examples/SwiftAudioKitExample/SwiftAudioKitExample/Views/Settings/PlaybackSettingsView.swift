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
                    .pickerStyle(.segmented)

                    Toggle("Shuffle", isOn: $player.isShuffled)
                }

                Section {
                    LabeledContent("Volume") {
                        HStack(spacing: 10) {
                            Image(systemName: "speaker.fill")
                            Slider(value: $player.volume, in: 0 ... 1)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 280)
                    }

                    LabeledContent("Rate") {
                        HStack(spacing: 12) {
                            Slider(value: $player.rate, in: 0.5 ... 2, step: 0.25)
                            Text(player.rate, format: .number.precision(.fractionLength(2)))
                                .font(.callout.monospacedDigit())
                                .frame(width: 40, alignment: .trailing)
                        }
                        .frame(maxWidth: 280)
                    }
                } header: {
                    Text("Output")
                } footer: {
                    Text("Rate applies to on-demand tracks. A live stream always plays at 1×.")
                }

                Section {
                    Picker("Preferred", selection: qualityBinding) {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            Text(quality.label).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Quality")
                } footer: {
                    Text("The nearest available stream is used, and metered connections drop to the reduced bitrate.")
                }

                Section("Current") {
                    LabeledContent("State", value: player.state.label)
                    LabeledContent("Source", value: player.progress.isLive ? "Live stream" : "On demand")
                    LabeledContent("Network", value: player.network.label)
                    LabeledContent("Metered", value: player.network.prefersReducedData ? "Yes" : "No")
                    if let duration = player.progress.duration {
                        LabeledContent("Duration", value: duration.formattedTime)
                    }
                }
            }
            .formStyle(.grouped)
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
