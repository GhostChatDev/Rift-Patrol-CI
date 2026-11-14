import Foundation

public struct SimReport: Sendable, Equatable {
    public let won: Bool
    public let wavesCleared: Int
    public let vanHP: Int
    public let kills: Int
    public let maxCombo: Int
    public let turretsBuilt: Int
    public let elapsed: Double
}

/// Headless, seeded battle over the 10 levels, used for balance checks and CI.
public enum BattleSim {
    private struct Foe {
        var enemy: GhostEnemy
        var distance: Double
        let speed: Double
        let damage: Int
    }

    public static func run(seed: UInt64, finalWave: Int = LevelCatalog.count, maxSeconds: Double = 1800) -> SimReport {
        var rng = SeededGenerator(seed: seed)
        var session = GameSession(finalWave: finalWave)
        var foes: [Foe] = []
        var time = 0.0, nextID = 0, spawned = 0, bossOut = false
        var spawnTimer = 0.0, playerCooldown = 0.0
        var turretCooldowns: [Double] = []
        var cleared = 0
        let dt = 0.05

        func nearest(_ foes: [Foe]) -> Int? {
            foes.indices.min { foes[$0].distance < foes[$1].distance }
        }
        func hit(_ i: Int, damage: Int, crit: Bool) {
            guard foes.indices.contains(i) else { return }
            _ = foes[i].enemy.receive(damage: damage, isCritical: crit)
            if !foes[i].enemy.isAlive {
                session.registerKill(at: time)
                foes.remove(at: i)
            }
        }

        while session.status == .playing && time < maxSeconds {
            time += dt
            session.tick(at: time)
            let spec = session.levelSpec

            if spec.hasBoss && !bossOut {
                foes.append(Foe(enemy: GhostEnemy(id: nextID, maxHP: spec.bossHP, shield: spec.bossShield),
                                distance: 100, speed: spec.bossSpeed, damage: spec.bossVanDamage))
                nextID += 1; bossOut = true
            }

            spawnTimer -= dt
            if spawned < spec.count && spawnTimer <= 0 {
                foes.append(Foe(enemy: GhostEnemy(id: nextID, maxHP: spec.hp, shield: spec.shield),
                                distance: 100, speed: spec.speed, damage: spec.vanDamage))
                nextID += 1; spawned += 1; spawnTimer = spec.spawnInterval
            }

            for i in foes.indices { foes[i].distance -= foes[i].speed * dt }
            let damage = foes.filter { $0.distance <= 0 }.reduce(0) { $0 + $1.damage }
            if damage > 0 {
                foes.removeAll { $0.distance <= 0 }
                session.damageVan(damage)
            }

            playerCooldown -= dt
            if playerCooldown <= 0, let t = nearest(foes) {
                playerCooldown = 0.25
                hit(t, damage: session.scaledDamage(14), crit: Double.random(in: 0..<1, using: &rng) < 0.2)
            }
            for (k, kind) in session.turrets.enumerated() {
                turretCooldowns[k] -= dt
                if turretCooldowns[k] <= 0, let t = nearest(foes) {
                    turretCooldowns[k] = kind.fireInterval
                    hit(t, damage: session.scaledDamage(kind.damage), crit: false)
                }
            }

            // Bot: alternate Tesla / Mortar whenever affordable.
            let want: TurretKind = session.turrets.count % 2 == 0 ? .monkeyTesla : .bulldogMortar
            if session.buyTurret(want) { turretCooldowns.append(0) }

            if spawned == spec.count && foes.isEmpty && session.status == .playing {
                session.completeWave()
                cleared += 1
                if session.status == .playing { spawned = 0; spawnTimer = 2.0; bossOut = false }
            }
        }
        return SimReport(won: session.status == .victory, wavesCleared: cleared, vanHP: session.vanHP,
                         kills: session.kills, maxCombo: session.combo.best,
                         turretsBuilt: session.turrets.count, elapsed: time)
    }
}
