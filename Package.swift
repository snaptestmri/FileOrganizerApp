// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileOrganizerApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "FileOrganizerApp",
            targets: ["FileOrganizerApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FileOrganizerApp",
            path: "FileOrganizerApp",
            exclude: [
                "Info.plist",
                "Entitlements.plist",
                "Docs",
                "Models/README.md",
                "scripts"
            ],
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit", "-framework", "SwiftUI", "-framework", "PDFKit"])
            ]
        ),
        .testTarget(
            name: "FileOrganizerAppTests",
            dependencies: ["FileOrganizerApp"],
            path: "Tests"
        )
    ]
) 