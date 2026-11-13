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
            path: "Sources/RiftPatrolCore"
        ),
        .executableTarget(
            name: "RiftPatrolSim",
            dependencies: ["RiftPatrolCore"],
            path: "Sources/RiftPatrolSim"
        ),
        .target(
            name: "RiftPatrolApp",
            dependencies: ["RiftPatrolCore"],
            path: "Sources/RiftPatrolApp"
        ),
        .testTarget(
            name: "RiftPatrolCoreTests",
            dependencies: ["RiftPatrolCore"],
            path: "Tests/RiftPatrolCoreTests"
        )
    ]
)
