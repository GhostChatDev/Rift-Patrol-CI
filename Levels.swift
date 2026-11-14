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
        case .sprinter: return "Very fast ghosts. Keep your aim moving."
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

    public var hasBoss: Bool { bossHP > 0 }
    public var bossShield: Int { shield * 2 }
    public var bossSpeed: Double { speed * 0.4 }
    public var bossVanDamage: Int { vanDamage * 3 }
    public var isFinal: Bool { number == LevelCatalog.count }
}

/// Ten levels, two laps of the five categories. Lap two is brutally hard;
/// level 10 (The Rift King) is the hardest and only just winnable.
public enum LevelCatalog {
    public static let count = 10
    /// Van HP restored after each cleared level.
    public static let repairBetweenLevels = 20

    private static let names = [
        "Rookie Rift", "Iron Veil", "Cold Dash", "Wobble Night", "The Gatekeeper",
        "Endless Tide", "Ghostplate", "Lightning Wake", "Mirage Storm", "The Rift King"
    ]

    /// Player and turret damage multiplier: +18% per level.
    public static func firepower(forLevel level: Int) -> Double {
        1.0 + 0.18 * Double(min(max(1, level), count) - 1)
    }

    public static var all: [LevelSpec] { (1...count).map { spec(forLevel: $0) } }

    public static func spec(forLevel level: Int) -> LevelSpec {
        let n = min(max(1, level), count)
        let lap2 = n > 5
        let base = WaveDirector.spec(forWave: lap2 ? n - 3 : n)
        let category = LevelCategory.allCases[(n - 1) % LevelCategory.allCases.count]
        let hardness = lap2 ? 1.5 : 1.0
        var ghosts = Double(base.count)
        var hp = Double(base.hp) * hardness
        var shield = Double(base.shield) * hardness
        var speed = base.speed * (lap2 ? 1.2 : 1.0)
        var interval = base.spawnInterval * (lap2 ? 0.85 : 1.0)
        var zigzag = 0.0
        var boss = 0
        switch category {
        case .swarm: ghosts *= 1.7; hp *= 0.55; interval *= 0.6
        case .armored: hp *= 1.1; shield = shield * 2.2 + 20; speed *= 0.8
        case .sprinter: speed *= 1.7; hp *= 0.8; ghosts *= 1.2
        case .phantom: zigzag = lap2 ? 110 : 70; hp *= 1.1; shield += 10
        case .siege: ghosts *= 0.6; boss = Int(hp * 9)
        }
        if n == count { ghosts *= 1.2; hp *= 1.15; boss = Int(Double(boss) * 1.4) }
        return LevelSpec(
            number: n, category: category, name: names[n - 1],
            count: max(3, Int(ghosts.rounded())), hp: max(1, Int(hp.rounded())),
            shield: max(0, Int(shield.rounded())), speed: speed,
            spawnInterval: max(0.35, interval), zigzag: zigzag, bossHP: boss,
            vanDamage: lap2 ? 12 : 10
        )
    }
}
