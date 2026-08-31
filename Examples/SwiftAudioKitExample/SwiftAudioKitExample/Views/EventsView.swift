//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI

struct EventsView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.log.entries.isEmpty {
                    ContentUnavailableView(
                        "No events yet",
                        systemImage: "waveform",
                        description: Text("Playback events appear here as they arrive.")
                    )
                } else {
                    List(model.log.entries) { entry in
                        row(for: entry)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem {
                    Button("Clear", systemImage: "trash") {
                        model.log.clear()
                    }
                    .disabled(model.log.entries.isEmpty)
                }
            }
        }
    }

    private func row(for entry: LoggedEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(entry.time, format: .dateTime.hour().minute().second())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(entry.isFailure ? Color.red : .primary)
                if let detail = entry.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
