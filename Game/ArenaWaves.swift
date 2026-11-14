import SpriteKit

/// Wave completion, turret buying, game over, victory and restart.
extension ArenaScene {
    func waveStep() {
        if session.status != .playing {
            announceEnd()
            return
        }
        let spec = WaveDirector.spec(forWave: session.wave)
        guard spawnedThisWave >= spec.count, enemies.isEmpty else { return }
        session.completeWave()
        if session.status == .playing {
            waveBreak = 2.5
            audio.play(.power)
            hud.showBanner("WAVE CLEARED")
        } else {
            announceEnd()
        }
    }

    func buyTurret(_ kind: TurretKind) {
        if session.buyTurret(kind) {
            audio.play(.power)
            hud.showBanner(kind.name)
        } else {
            audio.play(.hurt)
        }
    }

    private func announceEnd() {
        if session.status == .victory {
            audio.play(.power)
            hud.showBanner("VICTORY! Tap to play again")
        } else {
            hud.showBanner("GAME OVER. Tap to retry")
        }
        hud.update(session: session)
    }

    /// Starts a fresh run. Called by a tap once the game has ended.
    func restart() {
        for entry in enemies.values { entry.node.removeFromParent() }
        enemies.removeAll()
        session = GameSession(finalWave: 5)
        nextEnemyID = 0
        spawnedThisWave = 0
        spawnTimer = 0
        fireCooldown = 0
        turretTimers = []
        firing = false
        waveBreak = 2.0
        hud.update(session: session)
    }
}
