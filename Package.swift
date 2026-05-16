// swift-tools-version:5.9
// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
//
// Multipaste — clipboard history and snippet expansion for macOS.
// Source-available under PolyForm Strict 1.0.0. Noncommercial use only;
// commercial licensing: rohin.agrawal@gmail.com.
// Full license: ./LICENSE.md  |  REUSE metadata: ./REUSE.toml
// Canonical license URL: https://polyformproject.org/licenses/strict/1.0.0/

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
