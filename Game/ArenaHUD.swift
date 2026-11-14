#if canImport(SwiftUI) && canImport(SpriteKit)
import SpriteKit
import RiftPatrolCore

// Panels, HUD text, pause flow and input routing.
extension ArenaScene {
    func panel(title: String, subtitle: String) {
        overlay.removeAllChildren()
        let shade = box(size: size, at: CGPoint(x: 300, y: 450), fill: .black.withAlphaComponent(0.8), stroke: .clear, parent: overlay, radius: 0)
        shade.name = "shield"
        _ = box(size: CGSize(width: 540, height: 440), at: CGPoint(x: 300, y: 465), fill: SKColor(red: 0.035, green: 0.05, blue: 0.12, alpha: 1), stroke: cyan, parent: overlay)
        label(title, at: CGPoint(x: 300, y: 615), size: 32, color: cyan, parent: overlay)
        label(subtitle, at: CGPoint(x: 300, y: 570), size: 17, parent: overlay)
    }

    func showTitle() {
        mode = .title
        panel(title: "RIFT PATROL", subtitle: "THE LAST VAN BETWEEN WORLDS")
        label("Hold to fire. Defend the van.", at: CGPoint(x: 300, y: 512), size: 19, parent: overlay)
        label("10 levels, 5 categories, a boss each lap.", at: CGPoint(x: 300, y: 478), size: 17, parent: overlay)
        label("Buy companions with earned scrap.", at: CGPoint(x: 300, y: 446), size: 17, parent: overlay)
        label("PS5 / Xbox pad: left stick aims, R2 fires.", at: CGPoint(x: 300, y: 414), size: 16, color: gold, parent: overlay)
        label("BEST: \(best) BANISHMENTS", at: CGPoint(x: 300, y: 372), size: 18, color: pink, parent: overlay)
        button("START PATROL", id: "start", at: CGPoint(x: 300, y: 310), width: 290, parent: overlay)
    }

    func start() {
        for foe in foes.values { foe.node.removeFromParent() }
        for node in companions { node.removeFromParent() }
        foes.removeAll()
        companions.removeAll()
        turretClocks.removeAll()
        session = GameSession()
        nextID = 0
        spawned = 0
        bossSpawned = false
        elapsed = 0
        spawnClock = 1.5
        shotClock = 0
        pulseClock = 0
        intermission = 0
        aim = nil
        mode = .playing
        world.isPaused = false
        overlay.removeAllChildren()
        announceLevel()
        refreshHUD()
    }

    func refreshHUD() {
        hpLabel.text = "VAN \(session.vanHP)%"
        hpLabel.fontColor = session.vanHP < 30 ? pink : cyan
        levelLabel.text = "LEVEL \(session.level)/\(LevelCatalog.count)"
        scrapLabel.text = "SCRAP \(session.scrap)  •  KILLS \(session.kills)"
        comboLabel.text = session.comboBanner
        buttons["tesla"]?.alpha = session.scrap >= TurretKind.monkeyTesla.cost && session.turrets.count < GameSession.turretSlots ? 1 : 0.45
        buttons["mortar"]?.alpha = session.scrap >= TurretKind.bulldogMortar.cost && session.turrets.count < GameSession.turretSlots ? 1 : 0.45
        if let text = buttons["pulse"]?.children.first as? SKLabelNode {
            text.text = pulseClock > 0 ? "PULSE \(Int(ceil(pulseClock)))s" : "PULSE READY"
        }
        if let text = buttons["sound"]?.children.first as? SKLabelNode { text.text = muted ? "SOUND OFF" : "SOUND ON" }
    }

    func banner(_ text: String, at point: CGPoint = CGPoint(x: 300, y: 680), size: CGFloat = 23, color: SKColor? = nil) {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = text
        node.fontSize = size
        node.fontColor = color ?? cyan
        node.position = point
        node.zPosition = 90
        world.addChild(node)
        node.run(.sequence([.wait(forDuration: 1.9), .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    func finish() {
        mode = .ended
        aim = nil
        let won = session.status == .victory
        UserDefaults.standard.set(max(best, session.kills), forKey: "rift.bestKills")
        panel(title: won ? "RIFT SEALED!" : "VAN OVERRUN",
              subtitle: won ? "ALL 10 LEVELS CLEARED. THE PATROL LIVES ON." : "LEVEL \(session.level) OF \(LevelCatalog.count). ONE MORE RUN.")
        label("\(session.kills) KILLS • BEST COMBO \(session.combo.best)", at: CGPoint(x: 300, y: 500), size: 19, parent: overlay)
        label("VAN \(session.vanHP)% • LEVEL \(session.level)/\(LevelCatalog.count)", at: CGPoint(x: 300, y: 458), size: 19, color: cyan, parent: overlay)
        label("\(session.levelSpec.category.title) • \(session.levelSpec.name.uppercased())", at: CGPoint(x: 300, y: 420), size: 16, color: gold, parent: overlay)
        label("RECORD: \(best) BANISHMENTS", at: CGPoint(x: 300, y: 384), size: 18, color: pink, parent: overlay)
        button("PLAY AGAIN", id: "start", at: CGPoint(x: 300, y: 320), width: 290, parent: overlay)
    }

    func togglePause() {
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

    func sound(_ cue: ArcadeAudio.Cue) { if !muted { audio.play(cue) } }

    func press(_ point: CGPoint) {
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
}
#endif
