// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ActorsStudio",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
        .tvOS(.v17),
        .watchOS(.v10),
        ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ActorsStudio",
            targets: ["ActorsStudio"]),
        
        .library(
            name: "Examples",
            targets: ["ActorsStudio", "Examples"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ActorsStudio"),
        .target(
            name: "Examples",
            dependencies: ["ActorsStudio"]
        ),
        .testTarget(
            name: "ActorsStudioTests",
            dependencies: ["ActorsStudio"]
        ),
    ]
)
