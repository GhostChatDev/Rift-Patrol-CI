import SpriteKit

/// The playfield: scene setup, state and touch input.
/// Battle rules live in ArenaBattle.swift, labels in ArenaHUD.swift.
final class ArenaScene: SKScene {
    var session = GameSession(finalWave: 5)
    var enemies: [Int: (node: SKShapeNode, state: GhostEnemy)] = [:]
    var nextEnemyID = 0
    var spawnedThisWave = 0
    var spawnTimer = 0.0
    var fireCooldown = 0.0
    var turretTimers: [Double] = []
    var lastUpdate = 0.0
    var aimAngle = Double.pi / 2
    var firing = false
    var touchHeld = false
    var waveBreak = 2.0
    let van = SKShapeNode(rectOf: CGSize(width: 70, height: 36), cornerRadius: 8)
    let barrel = SKShapeNode(rectOf: CGSize(width: 6, height: 34), cornerRadius: 3)
    let hud = ArenaHUD()
    let audio = ArcadeAudio()
    let controller = ControllerInput()

    var vanPosition: CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.14) }
    var riftPosition: CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.88) }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.03, blue: 0.10, alpha: 1)
        van.fillColor = SKColor(red: 0.2, green: 0.75, blue: 0.9, alpha: 1)
        van.strokeColor = .white
        van.position = vanPosition
        van.zPosition = 5
        addChild(van)
        barrel.fillColor = .white
        barrel.strokeColor = .clear
        barrel.position = vanPosition
        barrel.zPosition = 6
        addChild(barrel)
        addChild(hud.node)
        hud.layout(in: size)
        hud.update(session: session)
        controller.start()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard van.parent != nil else { return }
        van.position = vanPosition
        barrel.position = vanPosition
        hud.layout(in: size)
    }

    // MARK: Touch: drag to aim, hold to fire

    private func aim(at point: CGPoint) {
        let dx = point.x - vanPosition.x
        let dy = max(point.y - vanPosition.y, 1)
        aimAngle = Double(atan2(dy, dx))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        if hud.handleTap(at: point, scene: self) { return }
        aim(at: point)
        firing = true
        touchHeld = true
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        aim(at: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        firing = false
        touchHeld = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        firing = false
        touchHeld = false
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.05)
        lastUpdate = currentTime
        guard session.status == .playing else { return }
        session.tick(at: currentTime)
        controller.apply(to: self, dt: dt)
        barrel.zRotation = CGFloat(aimAngle) - .pi / 2
        barrel.position = CGPoint(
            x: vanPosition.x + CGFloat(cos(aimAngle)) * 20,
            y: vanPosition.y + CGFloat(sin(aimAngle)) * 20)
        stepBattle(dt: dt, now: currentTime)
        hud.update(session: session)
    }
}
