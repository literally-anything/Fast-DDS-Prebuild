// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Fast-DDS-Prebuild",
    platforms: [
    	.macOS(.v10_13),
    	.iOS(.v12),
    	.visionOS(.v1)
    ],
    products: [
        .library(name: "Fast-DDS", targets: ["Fast-DDS"])
    ],
    targets: [
        .binaryTarget(
            name: "Fast-DDS",
            path: "Fast-DDS.xcframework"
        )
    ]
)
