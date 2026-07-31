// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TuckPup",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TuckPup", targets: ["TuckPup"])
    ],
    targets: [
        .executableTarget(
            name: "TuckPup",
            exclude: [
                "Resources"
            ]
        )
    ]
)
