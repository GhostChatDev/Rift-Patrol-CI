#if canImport(SwiftUI) && canImport(SpriteKit)
import SwiftUI
import SpriteKit

struct GameView: View {
    @State private var scene = ArenaScene(size: CGSize(width: 600, height: 900))

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onAppear { scene.scaleMode = .aspectFill }
    }
}
#endif
