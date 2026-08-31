//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI
import SwiftAudioKit

struct EqualizerView: View {
    @Environment(PlayerModel.self) private var model

    private var equalizer: EqualizerModel {
        model.equalizer
    }

    private var isAvailable: Bool {
        model.player.audioProcessing.isAvailable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !isAvailable {
                        unavailableNotice
                    }

                    header
                    presets
                    sliders
                    preamp
                }
                .padding(24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .disabled(!isAvailable)
                .opacity(isAvailable ? 1 : 0.5)
            }
            .navigationTitle("Equalizer")
        }
    }

    private var unavailableNotice: some View {
        Label(
            "Nothing that can be processed is playing. Start a station first.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.footnote)
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.orange.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    private var header: some View {
        HStack {
            Toggle("Enabled", isOn: enabledBinding)
                .toggleStyle(.switch)

            Spacer()

            Text(equalizer.preset?.displayName ?? "Custom")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: .capsule)

            Button("Reset", systemImage: "arrow.counterclockwise") {
                equalizer.reset()
            }
            .labelStyle(.iconOnly)
        }
    }

    private var presets: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(EqualizerPreset.allCases) { preset in
                    Button(preset.displayName) {
                        equalizer.apply(preset)
                    }
                    .buttonStyle(.bordered)
                    .tint(equalizer.preset == preset ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var sliders: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(equalizer.gains.enumerated()), id: \.offset) { index, gain in
                VStack(spacing: 6) {
                    Text(gain, format: .number.precision(.fractionLength(0)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(gain == 0 ? .secondary : .primary)

                    Slider(
                        value: gainBinding(at: index),
                        in: EqualizerModel.gainRange,
                        step: 0.5
                    )
                    .frame(height: 150)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 28, height: 150)

                    Text(label(for: EqualizerModel.frequencies[index]))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var preamp: some View {
        LabeledContent("Preamp") {
            HStack {
                Slider(value: globalGainBinding, in: EqualizerModel.gainRange, step: 0.5)
                Text(equalizer.globalGain, format: .number.precision(.fractionLength(1)))
                    .font(.caption.monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }

    private func label(for frequency: Double) -> String {
        frequency >= 1000 ? "\(Int(frequency / 1000))k" : "\(Int(frequency))"
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { equalizer.isEnabled }, set: { equalizer.isEnabled = $0 })
    }

    private var globalGainBinding: Binding<Float> {
        Binding(get: { equalizer.globalGain }, set: { equalizer.globalGain = $0 })
    }

    private func gainBinding(at index: Int) -> Binding<Float> {
        Binding(
            get: { equalizer.gains[index] },
            set: { equalizer.setGain($0, forBandAt: index) }
        )
    }
}
