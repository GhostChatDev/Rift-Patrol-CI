#if canImport(SwiftUI) && canImport(SpriteKit)
import SpriteKit
import RiftPatrolCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// The patrol itself: 10 levels in 5 categories, with a boss level at the end of each lap.
@MainActor
final class ArenaScene: SKScene {
    struct Foe {
        var ghost: GhostEnemy
        let node: SKNode
        let health: SKShapeNode
        let speed: CGFloat
        let damage: Int
        let isBoss: Bool
        let zigzag: CGFloat
        let baseX: CGFloat
    }

    enum Mode { case title, playing, paused, ended }

    static let spawnY: CGFloat = 765
    static let vanLine: CGFloat = 285

    var mode = Mode.title
    var session = GameSession()
    var foes: [Int: Foe] = [:]
    var nextID = 0
    var spawned = 0
    var bossSpawned = false
    var spawnClock = 1.0
    var turretClocks: [Double] = []
    var lastTime = 0.0
    var elapsed = 0.0
    var shotClock = 0.0
    var pulseClock = 0.0
    var intermission = 0.0
    var aim: CGPoint?

    let world = SKNode()
    let hud = SKNode()
    let overlay = SKNode()
    let hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    let levelLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    let scrapLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    let comboLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    let van = SKNode()
    var companions: [SKNode] = []
    var buttons: [String: SKShapeNode] = [:]

    let reticle = SKShapeNode(circleOfRadius: 14)
    let pad = ControllerInput()
    var padState = ControllerInput.Snapshot()
    var padAim = CGPoint(x: 300, y: 520)
    var padAnnounced = false

    var best: Int { UserDefaults.standard.integer(forKey: "rift.bestKills") }
    var muted = UserDefaults.standard.bool(forKey: "rift.muted")
    let audio = ArcadeAudio()
    let cyan = SKColor(red: 0.2, green: 0.95, blue: 1, alpha: 1)
    let pink = SKColor(red: 1, green: 0.3, blue: 0.65, alpha: 1)
    let violet = SKColor(red: 0.66, green: 0.42, blue: 1, alpha: 1)
    let gold = SKColor(red: 1, green: 0.84, blue: 0.25, alpha: 1)

    override func didMove(to view: SKView) {
        guard world.parent == nil else { return }
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.025, green: 0.035, blue: 0.09, alpha: 1)
        addChild(world)
        hud.zPosition = 100
        overlay.zPosition = 200
        addChild(hud)
        addChild(overlay)
        reticle.zPosition = 95
        reticle.strokeColor = gold
        reticle.lineWidth = 3
        reticle.glowWidth = 4
        reticle.isHidden = true
        world.addChild(reticle)
        buildArena()
        buildHUD()
        showTitle()
    }

    func label(_ text: String, at point: CGPoint, size: CGFloat = 20, color: SKColor = .white, parent: SKNode) {
        let node = SKLabelNode(fontNamed: "Menlo-Bold")
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.position = point
        parent.addChild(node)
    }

    @discardableResult
    func box(size: CGSize, at point: CGPoint, fill: SKColor, stroke: SKColor, parent: SKNode, radius: CGFloat = 12) -> SKShapeNode {
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

    func button(_ title: String, id: String, at point: CGPoint, width: CGFloat, parent: SKNode) {
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
        for (node, point) in [(hpLabel, CGPoint(x: 115, y: 849)), (levelLabel, CGPoint(x: 430, y: 849)), (scrapLabel, CGPoint(x: 300, y: 818)), (comboLabel, CGPoint(x: 300, y: 735))] {
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
        label("HOLD TO FIRE • AIM AT GHOSTS • CONTROLLER READY", at: CGPoint(x: 300, y: 39), size: 14, color: .lightGray, parent: hud)
        refreshHUD()
    }

    private func addController() {
        padState = pad.poll()
        guard padState.isConnected else { return }
        if !padAnnounced {
            padAnnounced = true
            reticle.isHidden = false
            popup(padState.name.uppercased() + " READY", at: CGPoint(x: 300, y: 700), color: gold)
        }
        let step = 620.0 * padState.dt
        padAim.x = min(560, max(40, padAim.x + padState.aim.x * step))
        padAim.y = min(790, max(215, padAim.y + padState.aim.y * step))
        reticle.position = padAim
        if padState.confirm {
            if mode == .title || mode == .ended { start() }
            else if mode == .paused { togglePause() }
        }
        if padState.menu, mode == .playing || mode == .paused { togglePause() }
        guard mode == .playing else {
            aim = nil
            return
        }
        aim = padState.firing ? padAim : nil
        if padState.pulse { pulse() }
        if padState.tesla { buy(.monkeyTesla) }
        if padState.mortar { buy(.bulldogMortar) }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : min(0.05, max(0, currentTime - lastTime))
        lastTime = currentTime
        addController()
        guard mode == .playing else { return }
        elapsed += dt
        session.tick(at: elapsed)
        shotClock -= dt
        pulseClock = max(0, pulseClock - dt)
        if let aim, shotClock <= 0 { shoot(at: aim); shotClock = 0.16 }
        tickLevel(dt: dt)
        moveFoes(dt: dt)
        if session.status != .playing { finish(); refreshHUD(); return }
        tickTurrets(dt: dt)
        checkLevelCleared()
        refreshHUD()
    }

    func pauseForBackground() {
        if mode == .playing { togglePause() }
        aim = nil
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
