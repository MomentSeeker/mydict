// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MyDict",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MyDictApp", targets: ["MyDictApp"]),
        .library(name: "MyDictCore", targets: ["MyDictCore"])
    ],
    targets: [
        .target(
            name: "MyDictCore",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "MyDictApp",
            dependencies: ["MyDictCore"]
        ),
        .testTarget(
            name: "MyDictAppTests",
            dependencies: ["MyDictApp", "MyDictCore"]
        )
    ]
)
