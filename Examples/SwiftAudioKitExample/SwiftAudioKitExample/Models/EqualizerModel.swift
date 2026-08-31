//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import AVFAudio
import Observation

/// A ten-band graphic equalizer built on `AVAudioUnitEQ`.
///
/// The unit is handed to `player.audioProcessing.units`, and everything here writes straight
/// into it. Its parameters are safe to set while audio renders, so moving a slider is heard
/// immediately.
@Observable
@MainActor
final class EqualizerModel {
    static let frequencies: [Double] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    static let gainRange: ClosedRange<Float> = -12 ... 12

    @ObservationIgnored let unit = AVAudioUnitEQ(numberOfBands: frequencies.count)

    var isEnabled = false {
        didSet { unit.bypass = !isEnabled }
    }

    var globalGain: Float = 0 {
        didSet { unit.globalGain = globalGain }
    }

    private(set) var gains = [Float](repeating: 0, count: frequencies.count)
    private(set) var preset: EqualizerPreset? = .flat

    init() {
        unit.bypass = true
        for (index, band) in unit.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = Float(Self.frequencies[index])
            band.bandwidth = 1
            band.gain = 0
            band.bypass = false
        }
    }

    func setGain(_ gain: Float, forBandAt index: Int) {
        guard gains.indices.contains(index) else {
            return
        }
        let clamped = min(max(gain, Self.gainRange.lowerBound), Self.gainRange.upperBound)
        gains[index] = clamped
        unit.bands[index].gain = clamped
        preset = Self.matchingPreset(for: gains)
    }

    func apply(_ preset: EqualizerPreset) {
        for (index, gain) in preset.gains.enumerated() {
            gains[index] = gain
            unit.bands[index].gain = gain
        }
        self.preset = preset
    }

    func reset() {
        apply(.flat)
        globalGain = 0
    }

    private static func matchingPreset(for gains: [Float]) -> EqualizerPreset? {
        EqualizerPreset.allCases.first { preset in
            zip(preset.gains, gains).allSatisfy { abs($0 - $1) < 0.01 }
        }
    }
}

/// A named curve across ``EqualizerModel/frequencies``.
enum EqualizerPreset: String, CaseIterable, Identifiable {
    case flat, bassBoost, bassReduce, trebleBoost, trebleReduce
    case loudness, speech, rock, jazz, classical, electronic

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .flat: "Flat"
        case .bassBoost: "Bass Boost"
        case .bassReduce: "Bass Reduce"
        case .trebleBoost: "Treble Boost"
        case .trebleReduce: "Treble Reduce"
        case .loudness: "Loudness"
        case .speech: "Speech"
        case .rock: "Rock"
        case .jazz: "Jazz"
        case .classical: "Classical"
        case .electronic: "Electronic"
        }
    }

    var gains: [Float] {
        switch self {
        case .flat: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bassBoost: [9, 7, 5, 2, 0, 0, 0, 0, 0, 0]
        case .bassReduce: [-9, -7, -5, -2, 0, 0, 0, 0, 0, 0]
        case .trebleBoost: [0, 0, 0, 0, 0, 2, 4, 6, 8, 9]
        case .trebleReduce: [0, 0, 0, 0, 0, -2, -4, -6, -8, -9]
        case .loudness: [9, 6, 3, 0, -3, -3, 0, 3, 6, 9]
        case .speech: [-6, -4, 0, 4, 7, 7, 5, 3, 0, -3]
        case .rock: [7, 5, 3, -1, -3, 0, 3, 6, 7, 7]
        case .jazz: [4, 3, 1, 3, -2, -2, 0, 2, 3, 4]
        case .classical: [5, 4, 2, 0, 0, 0, 0, 2, 4, 6]
        case .electronic: [8, 6, 2, 0, -3, 2, 0, 3, 6, 8]
        }
    }
}
