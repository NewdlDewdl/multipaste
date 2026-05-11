// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Multipaste",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Multipaste", targets: ["Multipaste"]),
        .executable(name: "MultipasteTests", targets: ["MultipasteTests"]),
        .library(name: "MultipasteCore", targets: ["MultipasteCore"]),
    ],
    targets: [
        .target(
            name: "MultipasteCore",
            path: "Sources/MultipasteCore"
        ),
        .executableTarget(
            name: "Multipaste",
            dependencies: ["MultipasteCore"],
            path: "Sources/Multipaste",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
            ]
        ),
        .executableTarget(
            name: "MultipasteTests",
            dependencies: ["MultipasteCore"],
            path: "Tests/MultipasteCoreTests"
        ),
    ]
)
