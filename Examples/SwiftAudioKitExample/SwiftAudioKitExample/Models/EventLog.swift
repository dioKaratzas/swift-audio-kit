//
//  SwiftAudioKitExample
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import Foundation
import SwiftAudioKit

struct LoggedEvent: Identifiable {
    let id = UUID()
    let time: Date
    let summary: String
    let detail: String?
    let isFailure: Bool
}

@Observable
@MainActor
final class EventLog {
    private(set) var entries: [LoggedEvent] = []

    var limit = 200

    func record(_ event: AudioPlayerEvent) {
        entries.insert(LoggedEvent(event), at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    func clear() {
        entries.removeAll()
    }
}

private extension LoggedEvent {
    init(_ event: AudioPlayerEvent) {
        time = Date()

        switch event {
        case let .stateChanged(from, to):
            summary = "State"
            detail = "\(from.label) → \(to.label)"
            isFailure = to.isFailed
        case let .itemChanged(_, to):
            summary = "Track"
            detail = to?.displayTitle ?? "none"
            isFailure = false
        case let .itemFinished(item):
            summary = "Finished"
            detail = item.displayTitle
            isFailure = false
        case .queueExhausted:
            summary = "Queue empty"
            detail = nil
            isFailure = false
        case let .durationResolved(duration, _):
            summary = "Duration"
            detail = duration.formattedTime
            isFailure = false
        case let .metadataUpdated(metadata, _):
            summary = "Metadata"
            detail = [metadata.title, metadata.subtitle].compactMap(\.self).joined(separator: " — ")
            isFailure = false
        case let .qualityChanged(from, to):
            summary = "Quality"
            detail = "\(from.label) → \(to.label)"
            isFailure = false
        case let .networkChanged(status):
            summary = "Network"
            detail = status.label
            isFailure = !status.isUsable
        case let .interrupted(reason):
            summary = "Interrupted"
            detail = String(describing: reason)
            isFailure = false
        case let .interruptionEnded(shouldResume):
            summary = "Interruption ended"
            detail = shouldResume ? "resuming" : "staying paused"
            isFailure = false
        case let .recoverableErrorLogged(failure):
            summary = "Recovered"
            detail = failure.description
            isFailure = false
        case let .failed(error):
            summary = "Failed"
            detail = error.errorDescription
            isFailure = true
        }
    }
}
