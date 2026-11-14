import SpriteKit

extension ArenaScene {
    func startWave() {
        spawnedThisWave = 0
        spawnTimer = 0
        audio.play(.wave)
        hud.showBanner("WAVE \(session.wave)")
    }

    func spawnStep(dt: Double) {
        let spec = WaveDirector.spec(forWave: session.wave)
        guard spawnedThisWave < spec.count else { return }
        spawnTimer -= dt
        guard spawnTimer <= 0 else { return }
        spawnTimer = spec.spawnInterval
        spawnedThisWave += 1
        let id = nextEnemyID
        nextEnemyID += 1
        let node = SKShapeNode(circleOfRadius: 16)
        node.fillColor = SKColor(red: 0.7, green: 0.4, blue: 1, alpha: 0.9)
        node.strokeColor = .white
        let dx = CGFloat.random(in: -40...40)
        node.position = CGPoint(x: riftPosition.x + dx, y: riftPosition.y)
        addChild(node)
        let ghost = GhostEnemy(id: id, maxHP: spec.hp, shield: spec.shield)
        enemies[id] = (node: node, state: ghost)
    }
}
