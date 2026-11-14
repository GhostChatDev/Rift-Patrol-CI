import SpriteKit

/// Procedural art for Rift Patrol. No image files needed.
/// Every builder returns a ready-to-add SKNode.
enum RiftArt {
    static let violet = SKColor(red: 0.62, green: 0.30, blue: 1.0, alpha: 1)
    static let cyan = SKColor(red: 0.25, green: 0.90, blue: 1.0, alpha: 1)
    static let pink = SKColor(red: 1.0, green: 0.35, blue: 0.75, alpha: 1)

    /// A designed portal: glow, spinning rings, and a bright core.
    static func makePortal(radius: CGFloat = 70) -> SKNode {
        let root = SKNode()
        root.name = "portal"

        let glow = SKShapeNode(circleOfRadius: radius * 1.5)
        glow.fillColor = violet.withAlphaComponent(0.18)
        glow.strokeColor = .clear
        glow.glowWidth = 24
        glow.zPosition = -3
        glow.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 1.1),
            .scale(to: 0.94, duration: 1.1)
        ])))
        root.addChild(glow)

        let ringColors = [violet, cyan, pink]
        for i in 0..<3 {
            let r = radius * (1.0 - CGFloat(i) * 0.22)
            let ring = SKShapeNode(ellipseOf: CGSize(width: r * 2, height: r * 1.7))
            ring.strokeColor = ringColors[i]
            ring.lineWidth = 4 - CGFloat(i)
            ring.fillColor = .clear
            ring.glowWidth = 6
            ring.zPosition = CGFloat(i) - 2
            let turns: CGFloat = i % 2 == 0 ? .pi * 2 : -.pi * 2
            ring.run(.repeatForever(.rotate(byAngle: turns, duration: 5 + Double(i) * 2)))
            root.addChild(ring)
        }

        let core = SKShapeNode(circleOfRadius: radius * 0.38)
        core.fillColor = SKColor(red: 0.08, green: 0.0, blue: 0.2, alpha: 1)
        core.strokeColor = .white
        core.lineWidth = 2
        core.glowWidth = 10
        core.zPosition = 1
        core.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.7, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6)
        ])))
        root.addChild(core)

        root.addChild(makeSwirlSparks(radius: radius))
        return root
    }

    /// Sparks that orbit and fade around the portal.
    static func makeSwirlSparks(radius: CGFloat) -> SKNode {
        let holder = SKNode()
        holder.zPosition = 2
        let spawn = SKAction.run { [weak holder] in
            guard let holder else { return }
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3))
            spark.fillColor = [violet, cyan, pink].randomElement() ?? violet
            spark.strokeColor = .clear
            let angle = CGFloat.random(in: 0..<(.pi * 2))
            spark.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.85)
            holder.addChild(spark)
            let inward = SKAction.move(to: .zero, duration: Double.random(in: 0.7...1.3))
            inward.timingMode = .easeIn
            spark.run(.sequence([.group([inward, .fadeOut(withDuration: 1.0)]), .removeFromParent()]))
        }
        holder.run(.repeatForever(.sequence([spawn, .wait(forDuration: 0.06)])))
        return holder
    }
}
