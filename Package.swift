// swift-tools-version: 6.3

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("ExistentialAny")
]

let package = Package(
    name: "SwiftAudioKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
        .macCatalyst(.v18)
    ],
    products: [
        .library(
            name: "SwiftAudioKit",
            targets: ["SwiftAudioKit"]
        )
    ],
    targets: [
        .target(
            name: "SwiftAudioKit",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SwiftAudioKitTests",
            dependencies: ["SwiftAudioKit"],
            resources: [
                .copy("Resources/image.png")
            ],
            swiftSettings: swiftSettings
        )
    ]
)
