import Foundation

public enum GameStatus: Sendable, Equatable { case playing, gameOver, victory }

public struct GameSession: Sendable, Equatable {
    public static let maxVanHP = 100
    public static let turretSlots = 4

    public let finalWave: Int
    public private(set) var vanHP = GameSession.maxVanHP
    public private(set) var scrap = 0
    public private(set) var wave = 1
    public private(set) var kills = 0
    public private(set) var combo = ComboTracker()
    public private(set) var turrets: [TurretKind] = []
    public private(set) var status = GameStatus.playing

    public init(finalWave: Int = LevelCatalog.count) { self.finalWave = max(1, finalWave) }

    public var comboBanner: String { combo.tier.banner }

    /// Current level number (same as `wave`).
    public var level: Int { wave }
    public var levelSpec: LevelSpec { LevelCatalog.spec(forLevel: wave) }
    public var firepower: Double { LevelCatalog.firepower(forLevel: wave) }

    /// Applies the current level's firepower bonus to a base damage value.
    public func scaledDamage(_ base: Int) -> Int {
        max(1, Int((Double(base) * firepower).rounded()))
    }

    /// Returns the scrap gained from this kill.
    @discardableResult
    public mutating func registerKill(at time: Double) -> Int {
        guard status == .playing else { return 0 }
        combo.registerKill(at: time)
        kills += 1
        let base = 5 + wave
        let gained = Int((Double(base) * combo.tier.scrapMultiplier).rounded())
        scrap += gained
        return gained
    }

    public mutating func tick(at time: Double) { combo.update(at: time) }

    public mutating func damageVan(_ amount: Int) {
        guard status == .playing, amount > 0 else { return }
        vanHP = max(0, vanHP - amount)
        if vanHP == 0 { status = .gameOver }
    }

    @discardableResult
    public mutating func buyTurret(_ kind: TurretKind) -> Bool {
        guard status == .playing, turrets.count < Self.turretSlots, scrap >= kind.cost else { return false }
        scrap -= kind.cost
        turrets.append(kind)
        return true
    }

    /// Clears the current level. Repairs the van between levels; the last level wins the game.
    public mutating func completeWave() {
        guard status == .playing else { return }
        if wave >= finalWave {
            status = .victory
        } else {
            wave += 1
            vanHP = min(Self.maxVanHP, vanHP + LevelCatalog.repairBetweenLevels)
        }
    }
}
