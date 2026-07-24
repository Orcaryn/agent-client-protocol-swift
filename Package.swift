// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-acp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ACPModel", targets: ["ACPModel"]),
        .library(name: "ACP", targets: ["ACP"]),
        .library(name: "ACPProcess", targets: ["ACPProcess"]),
        .executable(name: "acp-trail", targets: ["ACPTrail"]),
        .executable(name: "acp-field-notes-agent", targets: ["ACPFieldNotesAgent"]),
        .executable(name: "acp-hello-agent", targets: ["ACPHelloAgent"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-subprocess.git",
            .upToNextMinor(from: "0.5.0")
        )
    ],
    targets: [
        .target(
            name: "ACPModel"
        ),
        .target(
            name: "ACP",
            dependencies: ["ACPModel"]
        ),
        .target(
            name: "ACPProcess",
            dependencies: [
                "ACP",
                "ACPModel",
                .product(name: "Subprocess", package: "swift-subprocess"),
            ]
        ),
        .target(
            name: "ACPTestSupport",
            dependencies: ["ACP", "ACPModel"],
            path: "Tests/Support"
        ),
        .executableTarget(
            name: "ACPTrail",
            dependencies: ["ACP", "ACPModel", "ACPProcess"],
            path: "Examples/ACPTrail"
        ),
        .executableTarget(
            name: "ACPFieldNotesAgent",
            dependencies: ["ACP", "ACPModel"],
            path: "Examples/ACPFieldNotesAgent"
        ),
        .executableTarget(
            name: "ACPHelloAgent",
            dependencies: ["ACP", "ACPModel"],
            path: "Examples/ACPHelloAgent"
        ),
        .testTarget(
            name: "ACPModelTests",
            dependencies: ["ACPModel"],
            resources: [
                .copy("Fixtures/acp-v1.19.0-schema.json")
            ]
        ),
        .testTarget(
            name: "ACPTests",
            dependencies: ["ACP", "ACPModel", "ACPTestSupport"]
        ),
        .testTarget(
            name: "ACPProcessTests",
            dependencies: ["ACP", "ACPModel", "ACPProcess", "ACPTestSupport"],
            exclude: ["Fixtures"]
        ),
    ]
)
