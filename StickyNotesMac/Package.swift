// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StickyNotesMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "StickyNotesMac",
            targets: ["StickyNotesMac"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .executableTarget(
            name: "StickyNotesMac",
            dependencies: [],
            path: ".",
            exclude: [
                "Info.plist",
                "StickyNotesApp",
                "build.sh",
                "Package.swift"
            ],
            sources: [
                "StickyNotesAppMain.swift",
                "Models",
                "Views",
                "ViewModels",
                "Services",
                "Documents",
                "DesignSystem.swift"
            ],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
