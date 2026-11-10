// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AdiumLogViewer",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "AdiumLogViewer",
            path: "Sources/AdiumLogViewer"
        ),
        .testTarget(
            name: "AdiumLogViewerTests",
            dependencies: ["AdiumLogViewer"],
            path: "Tests/AdiumLogViewerTests"
        )
    ]
)
