import SpriteKit

extension ArenaScene {
    /// Ghosts drift toward the van. Reaching it hurts the van.
    func moveEnemies(dt: Double) {
        let speed = WaveDirector.spec(forWave: session.wave).speed * 8
        for (id, entry) in enemies {
            let node = entry.node
            let dx = vanPosition.x - node.position.x
            let dy = vanPosition.y - node.position.y
            let dist = max(1, (dx * dx + dy * dy).squareRoot())
            let step = CGFloat(speed * dt)
            if dist <= step + 30 {
                node.removeFromParent()
                enemies[id] = nil
                session.damageVan(10)
                audio.play(.hurt)
            } else {
                node.position.x += dx / dist * step
                node.position.y += dy / dist * step
            }
        }
    }
}
