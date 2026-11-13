// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RiftPatrol",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RiftPatrolCore", targets: ["RiftPatrolCore"]),
        .executable(name: "RiftPatrolSim", targets: ["RiftPatrolSim"])
    ],
    targets: [
        .target(
            name: "RiftPatrolCore",
            path: ".",
            sources: [
                "BattleSim.swift",
                "Combo.swift",
                "GameSession.swift",
                "GhostEnemy.swift",
                "HitOutcome.swift",
                "SeededGenerator.swift",
                "Turret.swift",
                "WaveDirector.swift"
            ]
        ),
        .executableTarget(
            name: "RiftPatrolSim",
            dependencies: ["RiftPatrolCore"],
            path: ".",
            sources: ["main.swift"]
        ),
        .target(
            name: "RiftPatrolApp",
            dependencies: ["RiftPatrolCore"],
            path: ".",
            sources: ["AppInfo.swift"]
        ),
        .testTarget(
            name: "RiftPatrolCoreTests",
            dependencies: ["RiftPatrolCore"],
            path: ".",
            sources: ["RiftPatrolCoreTests.swift"]
        )
    ]
)
