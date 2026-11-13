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
    private enum Mode { case title, playing, paused, ended }
    private var mode = Mode.title
    private var session = GameSession()
    private var foes: [Int: Foe] = [:]
    private var nextID = 0
    private var spawned = 0
    private var spawnClock = 1.0
    private var turretClocks: [Double] = []
    private var lastTime = 0.0
    private var elapsed = 0.0
    private var shotClock = 0.0
    private var pulseClock = 0.0
    private var intermission = 0.0
    private var aim: CGPoint?
    private let world = SKNode()
    private let hud = SKNode()
    private let overlay = SKNode()
    private let hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let waveLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let scrapLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let comboLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let van = SKNode()
    private var companions: [SKNode] = []
    private var buttons: [String: SKShapeNode] = [:]
    private var best: Int { UserDefaults.standard.integer(forKey: "rift.bestKills") }
    private var muted = UserDefaults.standard.bool(forKey: "rift.muted")
    private let audio = ArcadeAudio()
    private let cyan = SKColor(red: 0.2, green: 0.95, blue: 1, alpha: 1)
    private let pink = SKColor(red: 1, green: 0.3, blue: 0.65, alpha: 1)

    override func didMove(to view: SKView) {
        guard world.parent == nil else { return }
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.025, green: 0.035, blue: 0.09, alpha: 1)
        addChild(world)
        hud.zPosition = 100
        overlay.zPosition = 200
        addChild(hud)
        addChild(overlay)
        buildArena()
        buildHUD()
        showTitle()
    }

    private func label(_ text: String, at point: CGPoint, size: CGFloat = 20, color: SKColor = .white, parent: SKNode) {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.position = point
        parent.addChild(node)
    }

    @discardableResult
    private func box(size: CGSize, at point: CGPoint, fill: SKColor, stroke: SKColor, parent: SKNode, radius: CGFloat = 12) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: radius)
        node.position = point
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = 2
        parent.addChild(node)
        return node
    }

    private func buildArena() {
        for x in stride(from: 0, through: 600, by: 50) {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 185))
            path.addLine(to: CGPoint(x: x, y: 790))
            let line = SKShapeNode(path: path)
            line.strokeColor = cyan.withAlphaComponent(0.06)
            world.addChild(line)
        }
        for y in stride(from: 190, through: 790, by: 50) {
            _ = box(size: CGSize(width: 600, height: 1), at: CGPoint(x: 300, y: y), fill: cyan.withAlphaComponent(0.05), stroke: .clear, parent: world)
        }
        for index in 0..<40 {
            let star = SKShapeNode(circleOfRadius: index.isMultiple(of: 3) ? 2 : 1)
            star.position = CGPoint(x: CGFloat((index * 137 + 23) % 580 + 10), y: CGFloat((index * 83) % 600 + 190))
            star.fillColor = cyan
            star.strokeColor = .clear
            star.alpha = 0.25
            star.run(.repeatForever(.sequence([.fadeAlpha(to: 0.65, duration: 1.5), .fadeAlpha(to: 0.15, duration: 1.5)])))
            world.addChild(star)
        }
        let rift = SKShapeNode(ellipseOf: CGSize(width: 220, height: 40))
        rift.position = CGPoint(x: 300, y: 770)
        rift.strokeColor = pink
        rift.fillColor = pink.withAlphaComponent(0.12)
        rift.glowWidth = 10
        rift.run(.repeatForever(.sequence([.scaleX(to: 1.2, duration: 1.4), .scaleX(to: 1, duration: 1.4)])))
        world.addChild(rift)
        _ = box(size: CGSize(width: 580, height: 3), at: CGPoint(x: 300, y: 205), fill: cyan, stroke: .clear, parent: world)
        van.position = CGPoint(x: 300, y: 245)
        world.addChild(van)
        _ = box(size: CGSize(width: 115, height: 57), at: .zero, fill: SKColor(white: 0.15, alpha: 1), stroke: cyan, parent: van)
        _ = box(size: CGSize(width: 40, height: 24), at: CGPoint(x: 28, y: 8), fill: cyan.withAlphaComponent(0.3), stroke: cyan, parent: van, radius: 5)
        label("RIFT", at: CGPoint(x: -23, y: 0), size: 13, color: cyan, parent: van)
        for x in [-35, 35] {
            _ = box(size: CGSize(width: 20, height: 15), at: CGPoint(x: x, y: -32), fill: .black, stroke: .gray, parent: van, radius: 5)
        }
    }

    private func button(_ title: String, id: String, at point: CGPoint, width: CGFloat, parent: SKNode) {
        let node = box(size: CGSize(width: width, height: 48), at: point, fill: SKColor(red: 0.07, green: 0.1, blue: 0.19, alpha: 1), stroke: cyan, parent: parent)
        node.name = id
        let text = SKLabelNode(fontNamed: "Menlo-Bold")
        text.text = title
        text.fontSize = 15
        text.verticalAlignmentMode = .center
        node.addChild(text)
        if parent === hud { buttons[id] = node }
    }

    private func buildHUD() {
        _ = box(size: CGSize(width: 580, height: 82), at: CGPoint(x: 300, y: 840), fill: SKColor(white: 0.035, alpha: 0.95), stroke: cyan.withAlphaComponent(0.3), parent: hud)
        for (node, point) in [(hpLabel, CGPoint(x: 115, y: 849)), (waveLabel, CGPoint(x: 430, y: 849)), (scrapLabel, CGPoint(x: 300, y: 818)), (comboLabel, CGPoint(x: 300, y: 735))] {
            node.position = point
            node.fontSize = 18
            hud.addChild(node)
        }
        hpLabel.fontColor = cyan
        comboLabel.fontColor = pink
        button("TESLA 40", id: "tesla", at: CGPoint(x: 110, y: 155), width: 170, parent: hud)
        button("MORTAR 70", id: "mortar", at: CGPoint(x: 300, y: 155), width: 170, parent: hud)
        button("PULSE", id: "pulse", at: CGPoint(x: 490, y: 155), width: 170, parent: hud)
        button("PAUSE", id: "pause", at: CGPoint(x: 110, y: 92), width: 170, parent: hud)
        button("RESTART", id: "restart", at: CGPoint(x: 300, y: 92), width: 170, parent: hud)
        button("SOUND", id: "sound", at: CGPoint(x: 490, y: 92), width: 170, parent: hud)
        label("HOLD TO FIRE • AIM AT GHOSTS", at: CGPoint(x: 300, y: 39), size: 15, color: .lightGray, parent: hud)
        refreshHUD()
    }

    private func panel(title: String, subtitle: String) {
        overlay.removeAllChildren()
        let shade = box(size: size, at: CGPoint(x: 300, y: 450), fill: .black.withAlphaComponent(0.8), stroke: .clear, parent: overlay, radius: 0)
        shade.name = "shield"
        _ = box(size: CGSize(width: 540, height: 440), at: CGPoint(x: 300, y: 465), fill: SKColor(red: 0.035, green: 0.05, blue: 0.12, alpha: 1), stroke: cyan, parent: overlay)
        label(title, at: CGPoint(x: 300, y: 615), size: 32, color: cyan, parent: overlay)
        label(subtitle, at: CGPoint(x: 300, y: 570), size: 17, parent: overlay)
    }

    private func showTitle() {
        mode = .title
        panel(title: "RIFT PATROL", subtitle: "THE LAST VAN BETWEEN WORLDS")
        label("Hold to fire. Defend the van.", at: CGPoint(x: 300, y: 510), size: 19, parent: overlay)
        label("Buy companions with earned scrap.", at: CGPoint(x: 300, y: 475), size: 17, parent: overlay)
        label("Pulse clears crowds. Survive 5 waves.", at: CGPoint(x: 300, y: 440), size: 17, parent: overlay)
        label("BEST: \(best) BANISHMENTS", at: CGPoint(x: 300, y: 390), size: 18, color: pink, parent: overlay)
        button("START PATROL", id: "start", at: CGPoint(x: 300, y: 320), width: 290, parent: overlay)
    }

    private func start() {
        for foe in foes.values { foe.node.removeFromParent() }
        for node in companions { node.removeFromParent() }
        foes.removeAll()
        companions.removeAll()
        turretClocks.removeAll()
        session = GameSession()
        nextID = 0
        spawned = 0
        elapsed = 0
        spawnClock = 1.5
        shotClock = 0
        pulseClock = 0
        intermission = 0
        aim = nil
        mode = .playing
        world.isPaused = false
        overlay.removeAllChildren()
        banner("WAVE 1 • RIFT OPENING")
        refreshHUD()
    }

    private func refreshHUD() {
        hpLabel.text = "VAN \(session.vanHP)%"
        hpLabel.fontColor = session.vanHP < 30 ? pink : cyan
        waveLabel.text = "WAVE \(session.wave)/\(session.finalWave)"
        scrapLabel.text = "SCRAP \(session.scrap)  •  KILLS \(session.kills)"
        comboLabel.text = session.comboBanner
        buttons["tesla"]?.alpha = session.scrap >= 40 && session.turrets.count < 4 ? 1 : 0.45
        buttons["mortar"]?.alpha = session.scrap >= 70 && session.turrets.count < 4 ? 1 : 0.45
        if let text = buttons["pulse"]?.children.first as? SKLabelNode {
            text.text = pulseClock > 0 ? "PULSE \(Int(ceil(pulseClock)))s" : "PULSE READY"
        }
        if let text = buttons["sound"]?.children.first as? SKLabelNode { text.text = muted ? "SOUND OFF" : "SOUND ON" }
    }

    private func banner(_ text: String) {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = text
        node.fontSize = 23
        node.fontColor = cyan
        node.position = CGPoint(x: 300, y: 680)
        node.zPosition = 90
        world.addChild(node)
        node.run(.sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    private func spawn() {
        let spec = WaveDirector.spec(forWave: session.wave)
        nextID += 1
        let node = SKNode()
        node.position = CGPoint(x: CGFloat.random(in: 48...552), y: 765)
        let body = SKShapeNode(ellipseOf: CGSize(width: 46, height: 53))
        body.fillColor = session.wave >= 4 ? pink.withAlphaComponent(0.75) : cyan.withAlphaComponent(0.65)
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
        foes[nextID] = Foe(ghost: GhostEnemy(id: nextID, maxHP: spec.hp, shield: spec.shield), node: node, health: health, speed: CGFloat(spec.speed * 6))
        spawned += 1
    }

    private func beam(from: CGPoint, to: CGPoint, color: SKColor) {
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

    private func burst(at point: CGPoint, color: SKColor, count: Int = 10) {
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

    private func popup(_ text: String, at point: CGPoint, color: SKColor) {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = text
        node.fontSize = 16
        node.fontColor = color
        node.position = point
        node.zPosition = 40
        world.addChild(node)
        node.run(.sequence([.group([.moveBy(x: 0, y: 42, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }

    private func damage(_ id: Int, amount: Int, critical: Bool = false) {
        guard var foe = foes[id] else { return }
        let result = foe.ghost.receive(damage: amount, isCritical: critical)
        foe.health.xScale = CGFloat(foe.ghost.hp) / CGFloat(foe.ghost.maxHP)
        if foe.ghost.shield == 0 { foe.node.childNode(withName: "ectoShield")?.removeFromParent() }
        if foe.ghost.isAlive {
            foes[id] = foe
            popup(result.popupText, at: foe.node.position, color: critical ? pink : .white)
            foe.node.run(.sequence([.scale(to: 1.15, duration: 0.05), .scale(to: 1, duration: 0.08)]))
        } else {
            let reward = session.registerKill(at: elapsed)
            burst(at: foe.node.position, color: cyan)
            popup("+\(reward) SCRAP", at: foe.node.position, color: cyan)
            foe.node.removeFromParent()
            foes.removeValue(forKey: id)
            sound(.banish)
        }
    }

    private func shoot(at point: CGPoint) {
        guard let target = foes.min(by: { distance($0.value.node.position, point) < distance($1.value.node.position, point) }), distance(target.value.node.position, point) < 85 else { return }
        beam(from: CGPoint(x: 300, y: 285), to: target.value.node.position, color: .yellow)
        damage(target.key, amount: 18, critical: distance(target.value.node.position, point) < 17)
        sound(.shot)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func buy(_ kind: TurretKind) {
        guard session.buyTurret(kind) else {
            popup(session.turrets.count >= 4 ? "ALL SLOTS FULL" : "NEED MORE SCRAP", at: CGPoint(x: 300, y: 340), color: pink)
            return
        }
        turretClocks.append(0)
        let node = SKNode()
        let positions: [CGFloat] = [95, 505, 175, 425]
        node.position = CGPoint(x: positions[companions.count], y: 255)
        let color: SKColor = kind == .monkeyTesla ? cyan : .orange
        _ = box(size: CGSize(width: 48, height: 32), at: .zero, fill: color.withAlphaComponent(0.3), stroke: color, parent: node)
        label(kind == .monkeyTesla ? "T" : "M", at: CGPoint(x: 0, y: -7), size: 21, color: color, parent: node)
        _ = box(size: CGSize(width: 10, height: 24), at: CGPoint(x: 0, y: 23), fill: color, stroke: .white, parent: node, radius: 3)
        world.addChild(node)
        companions.append(node)
        burst(at: node.position, color: color)
        sound(.power)
    }

    private func pulse() {
        guard pulseClock <= 0 else { return }
        pulseClock = 18
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.position = CGPoint(x: 300, y: 300)
        ring.strokeColor = pink
        ring.lineWidth = 4
        ring.glowWidth = 8
        world.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 35, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        for id in Array(foes.keys) { damage(id, amount: 65) }
        sound(.power)
    }

    private func finish() {
        mode = .ended
        aim = nil
        UserDefaults.standard.set(max(best, session.kills), forKey: "rift.bestKills")
        panel(title: session.status == .victory ? "RIFT SEALED!" : "VAN OVERRUN", subtitle: session.status == .victory ? "THE PATROL LIVES ANOTHER NIGHT" : "ONE MORE RUN. YOU HAVE GOT THIS.")
        label("\(session.kills) KILLS • BEST COMBO \(session.combo.best)", at: CGPoint(x: 300, y: 500), size: 19, parent: overlay)
        label("VAN \(session.vanHP)% • WAVE \(session.wave)/5", at: CGPoint(x: 300, y: 455), size: 19, color: cyan, parent: overlay)
        label("RECORD: \(best) BANISHMENTS", at: CGPoint(x: 300, y: 405), size: 18, color: pink, parent: overlay)
        button("PLAY AGAIN", id: "start", at: CGPoint(x: 300, y: 325), width: 290, parent: overlay)
    }

    func pauseForBackground() {
        if mode == .playing { togglePause() }
        aim = nil
    }

    private func togglePause() {
        aim = nil
        if mode == .playing {
            mode = .paused
            world.isPaused = true
            panel(title: "PATROL PAUSED", subtitle: "TAKE A BREATH. THE VAN IS SAFE.")
            button("RESUME", id: "resume", at: CGPoint(x: 300, y: 440), width: 290, parent: overlay)
            button("NEW PATROL", id: "start", at: CGPoint(x: 300, y: 355), width: 290, parent: overlay)
        } else if mode == .paused {
            mode = .playing
            world.isPaused = false
            overlay.removeAllChildren()
        }
    }

    private func sound(_ cue: ArcadeAudio.Cue) { if !muted { audio.play(cue) } }

    private func press(_ point: CGPoint) {
        let root = mode == .playing ? hud : overlay
        let action = root.nodes(at: point).compactMap { node -> String? in
            var candidate: SKNode? = node
            while let current = candidate, current !== root {
                if let name = current.name { return name }
                candidate = current.parent
            }
            return nil
        }.first
        switch action {
        case "start": start()
        case "resume": togglePause()
        case "pause": togglePause()
        case "restart": start()
        case "tesla": buy(.monkeyTesla)
        case "mortar": buy(.bulldogMortar)
        case "pulse": pulse()
        case "sound":
            muted.toggle()
            UserDefaults.standard.set(muted, forKey: "rift.muted")
        default:
            if mode == .playing && point.y > 205 && point.y < 790 {
                aim = point
                if shotClock <= 0 { shoot(at: point); shotClock = 0.16 }
            }
        }
        refreshHUD()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(0.05, max(0, currentTime - lastTime))
        lastTime = currentTime
        guard mode == .playing else { return }
        elapsed += dt
        session.tick(at: elapsed)
        shotClock -= dt
        pulseClock = max(0, pulseClock - dt)
        if let aim, shotClock <= 0 { shoot(at: aim); shotClock = 0.16 }
        let spec = WaveDirector.spec(forWave: session.wave)
        if intermission > 0 {
            intermission -= dt
        } else if spawned < spec.count {
            spawnClock -= dt
            if spawnClock <= 0 { spawn(); spawnClock = spec.spawnInterval }
        }
        for id in Array(foes.keys) {
            guard let foe = foes[id] else { continue }
            foe.node.position.y -= foe.speed * dt
            if foe.node.position.y <= 285 {
                session.damageVan(10)
                burst(at: foe.node.position, color: pink)
                foe.node.removeFromParent()
                foes.removeValue(forKey: id)
                van.run(.sequence([.moveBy(x: -7, y: 0, duration: 0.04), .moveBy(x: 14, y: 0, duration: 0.06), .moveBy(x: -7, y: 0, duration: 0.04)]))
                sound(.hurt)
            }
        }
        if session.status != .playing { finish(); refreshHUD(); return }
        for index in session.turrets.indices {
            turretClocks[index] -= dt
            guard turretClocks[index] <= 0, let target = foes.min(by: { $0.value.node.position.y < $1.value.node.position.y }) else { continue }
            let kind = session.turrets[index]
            turretClocks[index] = kind.fireInterval
            let point = target.value.node.position
            beam(from: companions[index].position, to: point, color: kind == .monkeyTesla ? cyan : .orange)
            if kind == .bulldogMortar {
                burst(at: point, color: .orange, count: 6)
                let victims = foes.filter { distance($0.value.node.position, point) <= 85 }.map(\.key)
                for id in victims { damage(id, amount: kind.damage) }
            } else { damage(target.key, amount: kind.damage) }
        }
        if spawned == spec.count && foes.isEmpty {
            session.completeWave()
            if session.status == .victory { finish() } else {
                spawned = 0
                spawnClock = 0
                intermission = 3
                banner("WAVE \(session.wave) • BUY COMPANIONS!")
                sound(.power)
            }
        }
        refreshHUD()
    }

    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first { press(touch.location(in: self)) }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if aim != nil, let touch = touches.first { aim = touch.location(in: self) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { aim = nil }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { aim = nil }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) { press(event.location(in: self)) }
    override func mouseDragged(with event: NSEvent) { if aim != nil { aim = event.location(in: self) } }
    override func mouseUp(with event: NSEvent) { aim = nil }
    override func keyDown(with event: NSEvent) {
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ": if mode == .playing { pulse() }
        case "p", "\u{1b}": if mode == .playing || mode == .paused { togglePause() }
        default: break
        }
    }
    #endif
}
#endif
