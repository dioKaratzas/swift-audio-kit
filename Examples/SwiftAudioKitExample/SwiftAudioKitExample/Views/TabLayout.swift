//
//  SwiftAudioKit
//
//  Copyright (c) 2026 Dionysios Karatzas. All rights reserved.
//

#if !os(macOS)
    import SwiftUI

    struct TabLayout: View {
        var body: some View {
            TabView {
                ForEach(Destination.allCases) { destination in
                    Tab(destination.rawValue, systemImage: destination.symbol) {
                        destination.view
                    }
                }
            }
        }
    }
#endif
