// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Presence",
    platforms: [
        .iOS(.v18), // or .iOS("26.0")
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "PresenceKit",
            targets: ["PresenceKit"]
        ),
    ],
    targets: [
        .target(
            name: "PresenceKit",
            path: "Presence",
            exclude: ["Resources/Presence.entitlements", "App/PresenceApp.swift", "Views"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "PresenceKitTests",
            dependencies: ["PresenceKit"],
            path: "PresenceTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
