//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI

enum Destination: String, CaseIterable, Identifiable {
    case nowPlaying = "Now Playing"
    case queue = "Queue"
    case settings = "Settings"
    case events = "Events"

    var id: Self {
        self
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "play.circle"
        case .queue: "list.bullet"
        case .settings: "slider.horizontal.3"
        case .events: "waveform.badge.magnifyingglass"
        }
    }

    @ViewBuilder var view: some View {
        switch self {
        case .nowPlaying: NowPlayingView()
        case .queue: QueueView()
        case .settings: PlaybackSettingsView()
        case .events: EventsView()
        }
    }
}

struct RootView: View {
    @Environment(PlayerModel.self) private var model

    var body: some View {
        content
            .task { await model.start() }
    }

    @ViewBuilder private var content: some View {
        #if os(macOS)
            SidebarLayout()
        #else
            TabLayout()
        #endif
    }
}
