import Foundation

/// Every level belongs to one category that changes how its ghosts behave.
public enum LevelCategory: String, Sendable, CaseIterable, Equatable {
    case swarm, armored, sprinter, phantom, siege

    public var title: String {
        switch self {
        case .swarm: return "SWARM"
        case .armored: return "ARMORED"
        case .sprinter: return "SPRINTER"
        case .phantom: return "PHANTOM"
        case .siege: return "SIEGE BOSS"
        }
    }

    public var tip: String {
        switch self {
        case .swarm: return "Crowds of weak ghosts. Use the pulse and mortars."
        case .armored: return "Thick ecto-shields. Aim for crits."
        case .sprinter: return "Very fast ghosts. Keep your finger moving."
        case .phantom: return "Ghosts weave side to side. Lead your shots."
        case .siege: return "A giant boss leads the wave. Focus it down."
        }
    }
}

public struct LevelSpec: Sendable, Equatable {
    public let number: Int
    public let category: LevelCategory
    public let name: String
    public let count: Int
    public let hp: Int
    public let shield: Int
    public let speed: Double
    public let spawnInterval: Double
    /// Sideways weave in points (0 = straight down).
    public let zigzag: Double
    /// Boss HP (0 = no boss in this level).
    public let bossHP: Int
    /// Van damage per ghost that gets through.
    public let vanDamage: Int
}

/// Ten levels, two laps of the five categories. Lap two is brutally hard.
public enum LevelCatalog {
    public static let count = 10

    private static let names = [
        "Rookie Rift", "Iron Veil", "Cold Dash", "Wobble Night", "The Gatekeeper",
        "Endless Tide", "Ghostplate", "Lightning Wake", "Mirage Storm", "The Rift King"
    ]

    public static func spec(forLevel level: Int) -> LevelSpec {
        let n = min(max(1, level), count)
        let base = WaveDirector.spec(forWave: n)
        let category = LevelCategory.allCases[(n - 1) % LevelCategory.allCases.count]
        let lap2 = n > 5
        let hardness = lap2 ? 1.5 : 1.0
        var count = Double(base.count)
        var hp = Double(base.hp) * hardness
        var shield = Double(base.shield) * hardness
        var speed = base.speed * (lap2 ? 1.25 : 1.0)
        var interval = base.spawnInterval * (lap2 ? 0.75 : 1.0)
        var zigzag = 0.0
        var boss = 0
        switch category {
        case .swarm: count *= 1.7; hp *= 0.55; interval *= 0.6
        case .armored: hp *= 1.1; shield = shield * 2.2 + 20; speed *= 0.8
        case .sprinter: speed *= 1.7; hp *= 0.8; count *= 1.2
        case .phantom: zigzag = lap2 ? 110 : 70; hp *= 1.1; shield += 10
        case .siege: count *= 0.6; boss = Int(hp * 9)
        }
        if n == count_final { count *= 1.3; hp *= 1.25; boss = Int(Double(boss) * 1.6) }
        return LevelSpec(
            number: n, category: category, name: names[n - 1],
            count: max(3, Int(count.rounded())), hp: max(1, Int(hp.rounded())),
            shield: max(0, Int(shield.rounded())), speed: speed,
            spawnInterval: max(0.35, interval), zigzag: zigzag, bossHP: boss,
            vanDamage: lap2 ? 14 : 10
        )
    }

    private static var count_final: Int { count }
}
