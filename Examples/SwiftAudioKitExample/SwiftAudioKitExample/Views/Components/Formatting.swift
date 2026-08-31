//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftAudioKit

extension Duration {
    var formattedTime: String {
        let total = Int(components.seconds)
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600

        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

extension PlaybackState {
    var label: String {
        switch self {
        case .idle: "Idle"
        case .loading: "Loading"
        case .buffering: "Buffering"
        case .playing: "Playing"
        case let .paused(_, reason): "Paused (\(reason))"
        case .waitingForConnection: "Waiting for connection"
        case .failed: "Failed"
        }
    }
}

extension AudioQuality {
    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

extension NetworkStatus {
    var label: String {
        switch reachability {
        case .unknown: "Unknown"
        case .unavailable: "Offline"
        case .available: interface.map(\.label) ?? "Online"
        }
    }

    var symbol: String {
        switch reachability {
        case .unknown: "questionmark.circle"
        case .unavailable: "wifi.slash"
        case .available: interface == .cellular ? "antenna.radiowaves.left.and.right" : "wifi"
        }
    }
}

extension NetworkStatus.Interface {
    var label: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .cellular: "Cellular"
        case .wired: "Wired"
        case .other: "Online"
        }
    }
}
