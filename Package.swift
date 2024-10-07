// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Fast-DDS-Prebuild",
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
