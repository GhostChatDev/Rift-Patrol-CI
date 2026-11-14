import SpriteKit

/// Player fire, turret fire and hit effects.
extension ArenaScene {
    private static let playerDamage = 12
    private static let fireDelay = 0.25
    /// How far off the aim line (radians) a ghost can be and still be hit.
    private static let aimTolerance = 0.14

    func fireStep(dt: Double, now: Double) {
        fireCooldown -= dt
        guard firing, fireCooldown <= 0 else { return }
        fireCooldown = Self.fireDelay
        audio.play(.shot)
        showTracer()
        guard let id = enemyOnAimLine() else { return }
        hit(id, damage: Self.playerDamage, critical: Double.random(in: 0...1) < 0.15, now: now)
    }

    func turretStep(dt: Double, now: Double) {
        let kinds = session.turrets
        while turretTimers.count < kinds.count { turretTimers.append(0) }
        for (index, kind) in kinds.enumerated() {
            turretTimers[index] -= dt
            guard turretTimers[index] <= 0, let id = nearestEnemy() else { continue }
            turretTimers[index] = kind.fireInterval
            hit(id, damage: kind.damage, critical: false, now: now)
        }
    }

    private func enemyOnAimLine() -> Int? {
        var best: (id: Int, distance: CGFloat)?
        for (id, entry) in enemies {
            let dx = entry.node.position.x - vanPosition.x
            let dy = entry.node.position.y - vanPosition.y
            let angle = Double(atan2(dy, dx))
            guard abs(angle - aimAngle) < Self.aimTolerance else { continue }
            let distance = (dx * dx + dy * dy).squareRoot()
            if best == nil || distance < best!.distance { best = (id, distance) }
        }
        return best?.id
    }

    private func nearestEnemy() -> Int? {
        enemies.min { lhs, rhs in
            distanceToVan(lhs.value.node) < distanceToVan(rhs.value.node)
        }?.key
    }

    private func distanceToVan(_ node: SKNode) -> CGFloat {
        let dx = node.position.x - vanPosition.x
        let dy = node.position.y - vanPosition.y
        return (dx * dx + dy * dy).squareRoot()
    }

    func hit(_ id: Int, damage: Int, critical: Bool, now: Double) {
        guard var entry = enemies[id] else { return }
        let outcome = entry.state.receive(damage: damage, isCritical: critical)
        let position = entry.node.position
        showPopup(outcome, at: position)
        if entry.state.isAlive {
            enemies[id] = entry
            entry.node.run(.sequence([.scale(to: 1.25, duration: 0.04), .scale(to: 1, duration: 0.08)]))
        } else {
            entry.node.removeFromParent()
            enemies[id] = nil
            session.registerKill(at: now)
            audio.play(.banish)
        }
    }

    private func showPopup(_ outcome: HitOutcome, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = outcome.popupText
        label.fontSize = 14 * CGFloat(outcome.scale)
        label.fontColor = outcome.kind == .normal ? .white : SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        label.zRotation = CGFloat(outcome.tiltDegrees) * .pi / 180
        label.position = position
        label.zPosition = 50
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 30, duration: 0.5), .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))
    }

    private func showTracer() {
        let path = CGMutablePath()
        path.move(to: barrel.position)
        let reach: CGFloat = max(size.width, size.height)
        path.addLine(to: CGPoint(
            x: barrel.position.x + CGFloat(cos(aimAngle)) * reach,
            y: barrel.position.y + CGFloat(sin(aimAngle)) * reach))
        let line = SKShapeNode(path: path)
        line.strokeColor = SKColor(red: 0.5, green: 0.95, blue: 1, alpha: 0.8)
        line.lineWidth = 2
        line.zPosition = 4
        addChild(line)
        line.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))
    }
}
