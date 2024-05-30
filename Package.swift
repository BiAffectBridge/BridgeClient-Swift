// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BridgeClient",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BridgeClient",
            targets: [
                "BridgeClient",
                "BridgeClientExtension",
                "BridgeClientUI",
            ]),
        .library(
            name: "BridgeClientAppExtension",
            targets: [
                "BridgeClient",
                "BridgeClientExtension",
            ]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/BiAffectBridge/BridgeArchiver-Swift.git",
                 from: "0.4.0"),
        .package(url: "https://github.com/BiAffectBridge/JsonModel-Swift.git",
                 from: "2.2.0"),
        .package(url: "https://github.com/BiAffectBridge/AssessmentModel-Swift.git",
                 from: "1.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .binaryTarget(name: "BridgeClient",
                      path: "Binaries/release/BridgeClient.xcframework"),
        
        .target(name: "BridgeClientExtension",
                dependencies: [
                    "BridgeClient",
                    .product(name: "BridgeArchiver", package: "BridgeArchiver-Swift"),
                    .product(name: "JsonModel", package: "JsonModel-Swift"),
                ]),
        .testTarget(name: "BridgeClientExtensionTests",
                    dependencies: [
                        "BridgeClient",
                        "BridgeClientExtension",
                    ],
                    resources: [.process("Resources")]),
        
        .target(name: "BridgeClientUI",
                dependencies: [
                    "BridgeClient",
                    "BridgeClientExtension",
                    .product(name: "JsonModel", package: "JsonModel-Swift"),
                    .product(name: "AssessmentModel", package: "AssessmentModel-Swift"),
                    .product(name: "AssessmentModelUI", package: "AssessmentModel-Swift"),
                ],
                resources: [.process("Resources")]),
        .testTarget(name: "BridgeClientUITests",
                    dependencies: [
                        "BridgeClient",
                        "BridgeClientUI",
                    ]),
    ]
)
