// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Dropzone_clone",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Dropzone_clone",
            dependencies: []
        ),
        .testTarget(
            name: "Dropzone_cloneTests",
            dependencies: ["Dropzone_clone"]
        ),
    ]
)