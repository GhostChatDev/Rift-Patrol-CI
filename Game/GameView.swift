import SwiftUI
import SpriteKit

/// SwiftUI wrapper that shows the arena. Put this in ContentView or use it as the root view.
struct GameView: View {
    @State private var scene: ArenaScene = {
        let scene = ArenaScene()
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .background(Color.black)
            .accessibilityLabel("Rift Patrol arena")
    }
}

#Preview {
    GameView()
}
