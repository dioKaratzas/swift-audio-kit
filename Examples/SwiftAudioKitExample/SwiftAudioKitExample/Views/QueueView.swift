//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI
import SwiftAudioKit

struct QueueView: View {
    @Environment(PlayerModel.self) private var model

    private var player: AudioPlayer {
        model.player
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Queue") {
                    ForEach(player.items) { item in
                        row(for: item)
                    }
                    .onDelete { offsets in
                        offsets.map { player.items[$0].id }.forEach(player.remove)
                    }
                    .onMove { offsets, destination in
                        guard let source = offsets.first else {
                            return
                        }
                        player.move(from: source, to: destination > source ? destination - 1 : destination)
                    }
                }

                Section("Library") {
                    ForEach(Catalog.all) { item in
                        Button {
                            player.insertNext(item)
                        } label: {
                            Label(item.displayTitle, systemImage: "text.insert")
                        }
                    }
                }
            }
            .navigationTitle("Queue")
            .toolbar {
                #if !os(macOS)
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                #endif
                ToolbarItem {
                    Button("Clear", systemImage: "trash", role: .destructive) {
                        player.removeAll()
                    }
                    .disabled(player.items.isEmpty)
                }
            }
        }
    }

    private func artwork(for item: AudioItem) -> Artwork? {
        player.currentItem?.id == item.id ? player.metadata.artwork : nil
    }

    private func row(for item: AudioItem) -> some View {
        Button {
            player.play(item.id)
        } label: {
            HStack(spacing: 12) {
                ArtworkView(artwork: artwork(for: item), cornerRadius: 6)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(Catalog.station(for: item))
                        .foregroundStyle(model.isSkipped(item) ? .secondary : .primary)
                    if player.currentItem?.id == item.id, let title = player.metadata.title {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if model.isSkipped(item) {
                    Image(systemName: "forward.end.circle")
                        .foregroundStyle(.orange)
                }
                if item.sources.availableQualities.count > 1 {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(.secondary)
                }
                if player.currentItem?.id == item.id {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.tint)
                        .symbolEffect(.variableColor, isActive: player.state.isPlaying)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button(model.isSkipped(item) ? "Include" : "Skip", systemImage: "forward.end") {
                model.toggleSkipped(item)
            }
            .tint(.orange)
        }
    }
}
