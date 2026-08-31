//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

import SwiftUI
import SwiftAudioKit

struct ArtworkView: View {
    let artwork: Artwork?
    var cornerRadius: CGFloat = 18

    var body: some View {
        content
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
    }

    @ViewBuilder private var content: some View {
        switch artwork {
        case let .url(url):
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholder.overlay { ProgressView() }
            }
        case let .data(data):
            if let image = PlatformImage(data: data) {
                Image(platformImage: image).resizable().scaledToFill()
            } else {
                placeholder
            }
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [.accentColor.opacity(0.35), .accentColor.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "waveform")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
        }
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
            self.init(nsImage: platformImage)
        #else
            self.init(uiImage: platformImage)
        #endif
    }
}
