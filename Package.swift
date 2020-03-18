// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CleanQuit",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "CleanQuit",
            targets: ["CleanQuit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/BlueSignals.git", from: "1.0.21"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "CleanQuit",
            dependencies: ["Signals"]),
        .testTarget(
            name: "CleanQuitTests",
            dependencies: ["CleanQuit"]),
    ]
)
