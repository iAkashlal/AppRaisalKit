// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppRaisalKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "AppRaisalKit",
            targets: ["AppRaisalKit"]),
    ],
    targets: [
        .target(
            name: "AppRaisalKit",
            dependencies: [],
            path: "Sources/AppRaisalKit"
        ),
        .testTarget(
            name: "AppRaisalKitTests",
            dependencies: ["AppRaisalKit"],
            path: "Tests/AppRaisalKitTests"
        ),
    ]
)
