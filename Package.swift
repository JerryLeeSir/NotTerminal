// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NotTerminal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NotTerminal", targets: ["NotTerminal"])
    ],
    dependencies: [
        .package(path: "Vendor/libghostty-spm")
    ],
    targets: [
        .executableTarget(
            name: "NotTerminal",
            dependencies: [
                .product(name: "GhosttyTerminal", package: "libghostty-spm")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NotTerminalTests",
            dependencies: ["NotTerminal"]
        )
    ]
)
