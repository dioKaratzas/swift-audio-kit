//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if os(macOS)
    import SwiftUI
    import SwiftAudioKit

    /// The Mac gets a sidebar with a persistent transport bar, rather than tabs that hide
    /// the controls behind a selection.
    struct SidebarLayout: View {
        @Environment(PlayerModel.self) private var model
        @State private var selection = Destination.nowPlaying

        var body: some View {
            NavigationSplitView {
                List(Destination.allCases, selection: $selection) { destination in
                    Label(destination.rawValue, systemImage: destination.symbol)
                        .tag(destination)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            } detail: {
                VStack(spacing: 0) {
                    selection.view
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider()
                    MiniTransportBar()
                }
            }
            .frame(minWidth: 720, minHeight: 480)
        }
    }

    struct MiniTransportBar: View {
        @Environment(PlayerModel.self) private var model

        private var player: AudioPlayer {
            model.player
        }

        var body: some View {
            HStack(spacing: 16) {
                ArtworkView(artwork: player.metadata.artwork, cornerRadius: 6)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.metadata.title ?? player.currentItem.map(Catalog.station) ?? "Nothing playing")
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    if let artist = player.metadata.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TransportControls(player: player)

                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill")
                    Slider(value: volumeBinding, in: 0 ... 1)
                        .frame(width: 100)
                }
                .foregroundStyle(.secondary)

                StateBadge(state: player.state)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }

        private var volumeBinding: Binding<Float> {
            Binding(
                get: { model.player.volume },
                set: { model.player.volume = $0 }
            )
        }
    }
#endif
