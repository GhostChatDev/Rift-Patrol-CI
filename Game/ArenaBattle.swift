import SpriteKit

/// The per-frame battle step. Each piece lives in its own small file:
/// ArenaSpawn (spawnStep, moveEnemies), ArenaCombat (fireStep, turretStep),
/// ArenaWaves (waveStep, buyTurret).
extension ArenaScene {
    func stepBattle(dt: Double, now: Double) {
        if waveBreak > 0 {
            waveBreak -= dt
            if waveBreak <= 0 { startWave() }
            return
        }
        spawnStep(dt: dt)
        moveEnemies(dt: dt)
        fireStep(dt: dt, now: now)
        turretStep(dt: dt, now: now)
        waveStep()
    }
}
