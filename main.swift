import Foundation
import RiftPatrolCore

// Usage: swift run RiftPatrolSim [runs]
let runs = max(1, CommandLine.arguments.dropFirst().first.flatMap { Int($0) } ?? 20)
var wins = 0
for seed in 1...runs {
    let report = BattleSim.run(seed: UInt64(seed))
    if report.won { wins += 1 }
    print("seed \(seed): won=\(report.won) waves=\(report.wavesCleared) vanHP=\(report.vanHP) kills=\(report.kills) maxCombo=\(report.maxCombo)")
}
print("Won \(wins) of \(runs)")