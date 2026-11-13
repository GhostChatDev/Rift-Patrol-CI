#if canImport(SwiftUI) && canImport(SpriteKit)
import SpriteKit
import RiftPatrolCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class ArenaScene: SKScene {
    private struct Foe {
        var ghost: GhostEnemy
        let node: SKNode
        let health: SKShapeNode
        let speed: CGFloat
    }

    private var session = GameSession()
    private var foes: [Int: Foe] = [:]
    private var nextID = 0
    private var spawned = 0
    private var spawnClock: TimeInterval = 0
    private var turretClocks: [TimeInterval] = []
    private var lastTime: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var paused = false
    private let hud = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let message = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let field = SKNode()

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.025, green: 0.035, blue: 0.10, alpha: 1)
        if field.parent == nil { buildScene() }
    }

    private func label(_ text: String, at position: CGPoint, size: CGFloat, color: SKColor = .white) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: "AvenirNext-Bold")
        node.text = text
        node.position = position
        node.fontSize = size
        node.fontColor = color
        node.verticalAlignmentMode = .center
        return node
    }

    private func buildScene() {
        addChild(field)
        let ground = SKShapeNode(rectOf: CGSize(width: 600, height: 150))
        ground.position = CGPoint(x: 300, y: 120)
        ground.fillColor = SKColor(red: 0.08, green: 0.13, blue: 0.20, alpha: 1)
        ground.strokeColor = .clear
        field.addChild(ground)
        let van = SKShapeNode(rectOf: CGSize(width: 190, height: 64), cornerRadius: 14)
        van.position = CGPoint(x: 300, y: 185)
        van.fillColor = .systemTeal
        van.strokeColor = .white
        field.addChild(van)
        field.addChild(label("RIFT PATROL", at: CGPoint(x: 300, y: 185), size: 20, color: .black))
        hud.position = CGPoint(x: 300, y: 850)
        hud.fontSize = 20
        hud.zPosition = 20
        addChild(hud)
        message.position = CGPoint(x: 300, y: 780)
        message.fontSize = 23
        message.fontColor = .yellow
        message.zPosition = 20
        addChild(message)
        addButton("TESLA 40", name: "tesla", x: 100)
        addButton("MORTAR 70", name: "mortar", x: 250)
        addButton("PAUSE", name: "pause", x: 390)
        addButton("RESTART", name: "restart", x: 520)
        showMessage("TAP GHOSTS TO SHOOT!", duration: 4)
        refreshHUD()
    }

    private func addButton(_ title: String, name: String, x: CGFloat) {
        let button = SKShapeNode(rectOf: CGSize(width: 125, height: 52), cornerRadius: 12)
        button.name = name
        button.position = CGPoint(x: x, y: 48)
        button.fillColor = SKColor(red: 0.16, green: 0.23, blue: 0.36, alpha: 1)
        button.strokeColor = .cyan
        button.zPosition = 25
        let text = label(title, at: .zero, size: 14)
        text.name = name
        button.addChild(text)
        addChild(button)
    }

    private func showMessage(_ text: String, duration: TimeInterval = 1.3) {
        message.removeAllActions()
        message.text = text
        if duration > 0 {
            message.run(.sequence([.wait(forDuration: duration), .run { [weak self] in self?.message.text = "" }]))
        }
    }

    private func refreshHUD() {
        hud.text = "WAVE \(session.wave)/\(session.finalWave)    VAN \(session.vanHP)    SCRAP \(session.scrap)"
    }

    private func spawn() {
        let spec = WaveDirector.spec(forWave: session.wave)
        nextID += 1
        let ghost = GhostEnemy(id: nextID, maxHP: spec.hp, shield: spec.shield)
        let node = SKNode()
        node.name = "ghost-\(nextID)"
        node.position = CGPoint(x: CGFloat.random(in: 65...535), y: 735)
        let body = SKShapeNode(circleOfRadius: 32)
        body.fillColor = spec.shield > 0 ? .systemPurple : .systemGreen
        body.strokeColor = .white
        body.lineWidth = 3
        node.addChild(body)
        node.addChild(label("••", at: CGPoint(x: 0, y: 3), size: 28, color: .black))
        let health = SKShapeNode(rectOf: CGSize(width: 54, height: 6), cornerRadius: 3)
        health.position = CGPoint(x: 0, y: 43)
        health.fillColor = .green
        health.strokeColor = .clear
        node.addChild(health)
        field.addChild(node)
        foes[nextID] = Foe(ghost: ghost, node: node, health: health, speed: CGFloat(spec.speed) * 3)
        spawned += 1
    }

    private func hit(_ id: Int, damage: Int, critical: Bool = false) {
        guard var foe = foes[id], session.status == .playing else { return }
        let outcome = foe.ghost.receive(damage: damage, isCritical: critical)
        let total = max(1, foe.ghost.maxHP + foe.ghost.maxShield)
        foe.health.xScale = CGFloat(foe.ghost.hp + foe.ghost.shield) / CGFloat(total)
        let popup = label(outcome.popupText, at: foe.node.position, size: 18, color: .yellow)
        popup.zPosition = 15
        field.addChild(popup)
        popup.run(.sequence([.group([.moveBy(x: 0, y: 40, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        if !foe.ghost.isAlive {
            foe.node.removeFromParent()
            foes.removeValue(forKey: id)
            session.registerKill(at: elapsed)
            if !session.comboBanner.isEmpty { showMessage(session.comboBanner) }
        } else {
            foes[id] = foe
        }
        refreshHUD()
    }

    override func update(_ currentTime: TimeInterval) {
        guard lastTime != 0 else { lastTime = currentTime; return }
        let dt = min(max(currentTime - lastTime, 0), 0.1)
        lastTime = currentTime
        guard !paused, session.status == .playing else { return }
        elapsed += dt
        session.tick(at: elapsed)
        let spec = WaveDirector.spec(forWave: session.wave)
        spawnClock -= dt
        if spawned < spec.count && spawnClock <= 0 {
            spawn()
            spawnClock = spec.spawnInterval
        }
        for id in Array(foes.keys) {
            guard let foe = foes[id] else { continue }
            foe.node.position.y -= foe.speed * CGFloat(dt)
            if foe.node.position.y <= 225 {
                foe.node.removeFromParent()
                foes.removeValue(forKey: id)
                session.damageVan(10)
            }
        }
        while turretClocks.count < session.turrets.count { turretClocks.append(0) }
        for index in session.turrets.indices {
            turretClocks[index] -= dt
            if turretClocks[index] <= 0, let target = foes.min(by: { $0.value.node.position.y < $1.value.node.position.y })?.key {
                let turret = session.turrets[index]
                hit(target, damage: turret.damage)
                turretClocks[index] = turret.fireInterval
            }
        }
        if session.status == .gameOver {
            showMessage("VAN LOST — TAP RESTART", duration: 0)
        } else if spawned == spec.count && foes.isEmpty {
            session.completeWave()
            if session.status == .victory {
                showMessage("VICTORY! TAP RESTART", duration: 0)
            } else {
                spawned = 0
                spawnClock = 2
                showMessage("WAVE \(session.wave) INCOMING!", duration: 2)
            }
        }
        refreshHUD()
    }

    private func interact(at point: CGPoint) {
        let names = nodes(at: point).compactMap { $0.name ?? $0.parent?.name }
        if names.contains("restart") { restart(); return }
        if names.contains("pause") {
            guard session.status == .playing else { return }
            paused.toggle()
            showMessage(paused ? "PAUSED" : "RESUMED", duration: paused ? 0 : 1)
            return
        }
        guard !paused, session.status == .playing else { return }
        if names.contains("tesla") || names.contains("mortar") {
            let kind: TurretKind = names.contains("tesla") ? .monkeyTesla : .bulldogMortar
            showMessage(session.buyTurret(kind) ? "\(kind.name) DEPLOYED!" : "NEED SCRAP OR FREE SLOT")
            refreshHUD()
            return
        }
        if let target = foes.filter({ hypot($0.value.node.position.x - point.x, $0.value.node.position.y - point.y) <= 45 }).min(by: {
            hypot($0.value.node.position.x - point.x, $0.value.node.position.y - point.y) < hypot($1.value.node.position.x - point.x, $1.value.node.position.y - point.y)
        })?.key {
            hit(target, damage: 25, critical: Int.random(in: 1...8) == 1)
        }
    }

    private func restart() {
        for foe in foes.values { foe.node.removeFromParent() }
        foes.removeAll()
        session = GameSession()
        nextID = 0
        spawned = 0
        spawnClock = 0
        turretClocks.removeAll()
        elapsed = 0
        paused = false
        lastTime = 0
        refreshHUD()
        showMessage("TAP GHOSTS TO SHOOT!", duration: 3)
    }

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { interact(at: touch.location(in: self)) }
    }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) { interact(at: event.location(in: self)) }
    #endif
}
#endif
