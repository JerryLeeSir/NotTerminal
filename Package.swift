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
        .package(url: "https://github.com/Lakr233/libghostty-spm.git", from: "1.5.2")
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
