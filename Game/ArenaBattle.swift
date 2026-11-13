#if canImport(SwiftUI) && canImport(SpriteKit)
import SpriteKit
import RiftPatrolCore

// Level flow, ghost spawning, movement and combat.
extension ArenaScene {
    func accent(for category: LevelCategory) -> SKColor {
        switch category {
        case .swarm: return cyan
        case .armored: return violet
        case .sprinter: return gold
        case .phantom: return pink
        case .siege: return SKColor(red: 1, green: 0.24, blue: 0.3, alpha: 1)
        }
    }

    func tickLevel(dt: Double) {
        let spec = session.levelSpec
        if spec.hasBoss && !bossSpawned {
            spawnBoss(spec)
            bossSpawned = true
        }
        if intermission > 0 {
            intermission -= dt
        } else if spawned < spec.count {
            spawnClock -= dt
            if spawnClock <= 0 {
                spawnGhost(spec)
                spawnClock = spec.spawnInterval
            }
        }
    }

    func moveFoes(dt: Double) {
        let weave = elapsed * 2.2
        for id in Array(foes.keys) {
            guard var foe = foes[id] else { continue }
            foe.node.position.y -= foe.speed * dt
            if foe.zigzag > 0 {
                let swing = sin(weave + Double(id) * 0.9)
                foe.node.position.x = min(560, max(40, foe.baseX + CGFloat(swing) * foe.zigzag))
            }
            if foe.node.position.y <= Self.vanLine {
                session.damageVan(foe.damage)
                burst(at: foe.node.position, color: foe.isBoss ? .red : pink, count: foe.isBoss ? 22 : 10)
                popup("-\(foe.damage) VAN", at: CGPoint(x: foe.node.position.x, y: 330), color: pink)
                foe.node.removeFromParent()
                foes.removeValue(forKey: id)
                van.run(.sequence([.moveBy(x: -7, y: 0, duration: 0.04), .moveBy(x: 14, y: 0, duration: 0.06), .moveBy(x: -7, y: 0, duration: 0.04)]))
                sound(.hurt)
                continue
            }
            foes[id] = foe
        }
    }

    func tickTurrets(dt: Double) {
        for index in session.turrets.indices {
            guard index < turretClocks.count else { continue }
            turretClocks[index] -= dt
            guard turretClocks[index] <= 0,
                  let target = foes.min(by: { $0.value.node.position.y < $1.value.node.position.y }) else { continue }
            let kind = session.turrets[index]
            turretClocks[index] = kind.fireInterval
            let point = target.value.node.position
            beam(from: companions[index].position, to: point, color: kind == .monkeyTesla ? cyan : .orange)
            if kind == .bulldogMortar {
                burst(at: point, color: .orange, count: 6)
                let victims = foes.filter { distance($0.value.node.position, point) <= 85 }.map(\.key)
                for id in victims { damage(id, amount: session.scaledDamage(kind.damage)) }
            } else {
                damage(target.key, amount: session.scaledDamage(kind.damage))
            }
        }
    }

    func checkLevelCleared() {
        let spec = session.levelSpec
        guard spawned >= spec.count, foes.isEmpty else { return }
        session.completeWave()
        if session.status == .victory {
            finish()
        } else {
            spawned = 0
            bossSpawned = false
            spawnClock = 0
            intermission = 3.0
            spawnClock = spec.spawnInterval
            announceLevel()
            sound(.power)
        }
    }

    /// Shows "LEVEL n/10 • NAME" plus the category tip for the level about to run.
    func announceLevel() {
        let spec = session.levelSpec
        banner("LEVEL \(spec.number)/\(LevelCatalog.count) • \(spec.name.uppercased())", color: accent(for: spec.category))
        banner(spec.category.title + " — " + spec.category.tip, at: CGPoint(x: 300, y: 640), size: 15, color: .lightGray)
    }

    func spawnGhost(_ spec: LevelSpec) {
        nextID += 1
        let id = nextID
        let node = SKNode()
        let baseX = CGFloat.random(in: 60...540)
        node.position = CGPoint(x: baseX, y: Self.spawnY)
        let color = accent(for: spec.category)
        let body = SKShapeNode(ellipseOf: CGSize(width: 46, height: 53))
        body.fillColor = color.withAlphaComponent(0.65)
        body.strokeColor = .white
        body.glowWidth = 4
        node.addChild(body)
        for x in [-9, 9] {
            _ = box(size: CGSize(width: 6, height: 10), at: CGPoint(x: x, y: 5), fill: .black, stroke: .clear, parent: node, radius: 2)
        }
        for x in [-15, 0, 15] {
            let tail = SKShapeNode(circleOfRadius: 8)
            tail.position = CGPoint(x: x, y: -22)
            tail.fillColor = body.fillColor
            tail.strokeColor = .clear
            node.addChild(tail)
        }
        if spec.shield > 0 {
            let shield = SKShapeNode(circleOfRadius: 34)
            shield.name = "ectoShield"
            shield.strokeColor = cyan
            shield.lineWidth = 2
            shield.glowWidth = 3
            node.addChild(shield)
        }
        let health = box(size: CGSize(width: 44, height: 4), at: CGPoint(x: 0, y: 40), fill: .green, stroke: .clear, parent: node, radius: 1)
        body.run(.repeatForever(.sequence([.rotate(toAngle: 0.12, duration: 0.4), .rotate(toAngle: -0.12, duration: 0.4)])))
        world.addChild(node)
        foes[id] = Foe(ghost: GhostEnemy(id: id, maxHP: spec.hp, shield: spec.shield), node: node,
                      health: health, speed: CGFloat(spec.speed * 6), damage: spec.vanDamage,
                      isBoss: false, zigzag: CGFloat(spec.zigzag), baseX: baseX)
        spawned += 1
    }

    func spawnBoss(_ spec: LevelSpec) {
        nextID += 1
        let id = nextID
        let node = SKNode()
        let baseX = CGFloat.random(in: 180...420)
        node.position = CGPoint(x: baseX, y: 720)
        let body = SKShapeNode(ellipseOf: CGSize(width: 150, height: 168))
        body.fillColor = SKColor(red: 0.75, green: 0.2, blue: 0.35, alpha: 0.85)
        body.strokeColor = gold
        body.lineWidth = 4
        body.glowWidth = 10
        node.addChild(body)
        let crown = SKShapeNode(path: {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -46, y: -20))
            path.addLine(to: CGPoint(x: -30, y: 20))
            path.addLine(to: CGPoint(x: -10, y: -14))
            path.addLine(to: CGPoint(x: 10, y: 20))
            path.addLine(to: CGPoint(x: 30, y: -14))
            path.addLine(to: CGPoint(x: 46, y: 20))
            return path
        }())
        crown.position = CGPoint(x: 0, y: 92)
        crown.strokeColor = gold
        crown.lineWidth = 5
        crown.glowWidth = 6
        node.addChild(crown)
        for x in [-34, 34] {
            let eye = SKShapeNode(circleOfRadius: 13)
            eye.position = CGPoint(x: x, y: 12)
            eye.fillColor = gold
            eye.strokeColor = .clear
            eye.glowWidth = 8
            node.addChild(eye)
        }
        let shield = SKShapeNode(circleOfRadius: 108)
        shield.name = "ectoShield"
        shield.strokeColor = cyan
        shield.lineWidth = 3
        shield.glowWidth = 6
        node.addChild(shield)
        let health = box(size: CGSize(width: 150, height: 7), at: CGPoint(x: 0, y: 104), fill: .green, stroke: .clear, parent: node, radius: 3)
        body.run(.repeatForever(.sequence([.rotate(toAngle: 0.05, duration: 0.9), .rotate(toAngle: -0.05, duration: 0.9)])))
        world.addChild(node)
        foes[id] = Foe(ghost: GhostEnemy(id: id, maxHP: spec.bossHP, shield: spec.bossShield), node: node,
                      health: health, speed: CGFloat(spec.bossSpeed * 6), damage: spec.bossVanDamage,
                      isBoss: true, zigzag: CGFloat(spec.zigzag) * 0.5, baseX: baseX)
        popup("BOSS: \(spec.name.uppercased())", at: CGPoint(x: 300, y: 660), color: gold)
    }

    func beam(from: CGPoint, to: CGPoint, color: SKColor) {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        let line = SKShapeNode(path: path)
        line.strokeColor = color
        line.lineWidth = 3
        line.glowWidth = 5
        line.zPosition = 10
        world.addChild(line)
        line.run(.sequence([.fadeOut(withDuration: 0.13), .removeFromParent()]))
    }

    func burst(at point: CGPoint, color: SKColor, count: Int = 10) {
        for _ in 0..<count {
            let particle = SKShapeNode(rectOf: CGSize(width: 5, height: 8))
            particle.position = point
            particle.fillColor = color
            particle.strokeColor = .clear
            particle.zPosition = 20
            world.addChild(particle)
            particle.run(.sequence([.group([.moveBy(x: CGFloat.random(in: -65...65), y: CGFloat.random(in: -60...60), duration: 0.45), .fadeOut(withDuration: 0.45), .rotate(byAngle: 4, duration: 0.45)]), .removeFromParent()]))
        }
    }

    func popup(_ text: String, at point: CGPoint, color: SKColor) {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = text
        node.fontSize = 16
        node.fontColor = color
        node.position = point
        node.zPosition = 40
        world.addChild(node)
        node.run(.sequence([.group([.moveBy(x: 0, y: 42, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }

    func damage(_ id: Int, amount: Int, critical: Bool = false) {
        guard var foe = foes[id] else { return }
        let result = foe.ghost.receive(damage: amount, isCritical: critical)
        foe.health.xScale = max(0, CGFloat(foe.ghost.hp) / CGFloat(foe.ghost.maxHP))
        if foe.ghost.shield == 0 { foe.node.childNode(withName: "ectoShield")?.removeFromParent() }
        if foe.ghost.isAlive {
            foes[id] = foe
            popup(result.popupText, at: foe.node.position, color: critical ? pink : (foe.isBoss ? gold : .white))
            foe.node.run(.sequence([.scale(to: 1.15, duration: 0.05), .scale(to: 1, duration: 0.08)]))
        } else {
            let reward = session.registerKill(at: elapsed)
            burst(at: foe.node.position, color: foe.isBoss ? gold : cyan, count: foe.isBoss ? 26 : 10)
            popup("+\(reward) SCRAP", at: foe.node.position, color: cyan)
            if foe.isBoss { popup("BOSS BANISHED!", at: CGPoint(x: 300, y: 600), color: gold) }
            foe.node.removeFromParent()
            foes.removeValue(forKey: id)
            sound(.banish)
        }
    }

    func shoot(at point: CGPoint) {
        guard let target = foes.min(by: { distance($0.value.node.position, point) < distance($1.value.node.position, point) }),
              distance(target.value.node.position, point) < (target.value.isBoss ? 130 : 85) else { return }
        beam(from: CGPoint(x: 300, y: 285), to: target.value.node.position, color: .yellow)
        damage(target.key, amount: session.scaledDamage(18), critical: distance(target.value.node.position, point) < 17)
        sound(.shot)
    }

    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    func buy(_ kind: TurretKind) {
        guard session.buyTurret(kind) else {
            popup(session.turrets.count >= GameSession.turretSlots ? "ALL SLOTS FULL" : "NEED MORE SCRAP", at: CGPoint(x: 300, y: 340), color: pink)
            return
        }
        turretClocks.append(0)
        let node = SKNode()
        let positions: [CGFloat] = [95, 505, 175, 425]
        node.position = CGPoint(x: positions[min(companions.count, positions.count - 1)], y: 255)
        let color: SKColor = kind == .monkeyTesla ? cyan : .orange
        _ = box(size: CGSize(width: 48, height: 32), at: .zero, fill: color.withAlphaComponent(0.3), stroke: color, parent: node)
        label(kind == .monkeyTesla ? "T" : "M", at: CGPoint(x: 0, y: -7), size: 21, color: color, parent: node)
        _ = box(size: CGSize(width: 10, height: 24), at: CGPoint(x: 0, y: 23), fill: color, stroke: .white, parent: node, radius: 3)
        world.addChild(node)
        companions.append(node)
        burst(at: node.position, color: color)
        sound(.power)
    }

    func pulse() {
        guard pulseClock <= 0, mode == .playing else { return }
        pulseClock = 18
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.position = CGPoint(x: 300, y: 300)
        ring.strokeColor = pink
        ring.lineWidth = 4
        ring.glowWidth = 8
        world.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 35, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        for id in Array(foes.keys) { damage(id, amount: session.scaledDamage(65)) }
        sound(.power)
    }
}
#endif
