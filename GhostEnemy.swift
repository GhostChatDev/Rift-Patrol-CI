import Foundation

/// A ghost with an ecto-shield layered over its HP.
public struct GhostEnemy: Sendable, Equatable {
    public let id: Int
    public let maxHP: Int
    public let maxShield: Int
    public private(set) var hp: Int
    public private(set) var shield: Int

    public var isAlive: Bool { hp > 0 }

    public static let critMultiplier = 2

    public init(id: Int, maxHP: Int, shield: Int = 0) {
        self.id = id
        self.maxHP = max(1, maxHP)
        self.maxShield = max(0, shield)
        self.hp = max(1, maxHP)
        self.shield = max(0, shield)
    }

    /// The shield absorbs damage first; the overflow carries into HP.
    public mutating func receive(damage: Int, isCritical: Bool) -> HitOutcome {
        guard isAlive, damage > 0 else { return HitOutcome(kind: .normal, dealt: 0) }
        let total = isCritical ? damage * Self.critMultiplier : damage
        var remaining = total
        var shieldBroke = false
        if shield > 0 {
            let absorbed = min(shield, remaining)
            shield -= absorbed
            remaining -= absorbed
            shieldBroke = shield == 0
        }
        let hpBefore = hp
        hp = max(0, hp - remaining)
        let dealt = total - (remaining - (hpBefore - hp))
        if hp == 0 { return HitOutcome(kind: .finisher, dealt: dealt) }
        if shieldBroke { return HitOutcome(kind: .shieldCrack, dealt: dealt) }
        return HitOutcome(kind: isCritical ? .critical : .normal, dealt: dealt)
    }
}