// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Cheers",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            exact: "0.18.0",
            traits: ["NemoTextProcessing"]
        )
    ],
    targets: [
        .target(name: "CheersCore"),
        .executableTarget(
            name: "Cheers",
            dependencies: [
                "CheersCore",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "CheersCoreTests", dependencies: ["CheersCore"]),
    ]
)
