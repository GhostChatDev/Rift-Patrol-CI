import SpriteKit

/// Labels, banners and the two turret buy buttons.
@MainActor
final class ArenaHUD {
    let node = SKNode()
    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let scrapLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let waveLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private var buttons: [(kind: TurretKind, node: SKShapeNode)] = []

    init() {
        node.zPosition = 100
        for label in [hpLabel, scrapLabel, waveLabel] {
            label.fontSize = 16
            label.fontColor = .white
            node.addChild(label)
        }
        comboLabel.fontSize = 22
        comboLabel.fontColor = SKColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        node.addChild(comboLabel)
        banner.fontSize = 34
        banner.fontColor = .white
        banner.alpha = 0
        node.addChild(banner)
        for kind in TurretKind.allCases {
            let button = SKShapeNode(rectOf: CGSize(width: 110, height: 40), cornerRadius: 10)
            button.fillColor = SKColor(white: 0.15, alpha: 0.85)
            button.strokeColor = .white
            let text = SKLabelNode(fontNamed: "AvenirNext-Bold")
            text.fontSize = 12
            text.fontColor = .white
            text.verticalAlignmentMode = .center
            text.text = (kind == .monkeyTesla ? "Tesla " : "Mortar ") + "\(kind.cost)"
            button.addChild(text)
            node.addChild(button)
            buttons.append((kind, button))
        }
    }

    func layout(in size: CGSize) {
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.position = CGPoint(x: 14, y: size.height - 34)
        scrapLabel.horizontalAlignmentMode = .right
        scrapLabel.position = CGPoint(x: size.width - 14, y: size.height - 34)
        waveLabel.horizontalAlignmentMode = .center
        waveLabel.position = CGPoint(x: size.width / 2, y: size.height - 34)
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        banner.position = CGPoint(x: size.width / 2, y: size.height * 0.5)
        for (index, item) in buttons.enumerated() {
            let side: CGFloat = index == 0 ? 70 : size.width - 70
            item.node.position = CGPoint(x: side, y: 40)
        }
    }

    func update(session: GameSession) {
        hpLabel.text = "Van HP \(session.vanHP)"
        scrapLabel.text = "Scrap \(session.scrap)"
        waveLabel.text = "Wave \(session.wave)/\(session.finalWave)"
        comboLabel.text = session.comboBanner
    }

    func showBanner(_ text: String) {
        banner.text = text
        banner.removeAllActions()
        banner.alpha = 1
        banner.run(.sequence([.wait(forDuration: 1.4), .fadeOut(withDuration: 0.5)]))
    }

    /// Returns true when the tap hit a button, so the scene doesn't also fire.
    func handleTap(at point: CGPoint, scene: ArenaScene) -> Bool {
        for item in buttons where item.node.frame.contains(point) {
            scene.buyTurret(item.kind)
            return true
        }
        return false
    }
}
