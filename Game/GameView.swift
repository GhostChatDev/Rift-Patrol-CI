#if canImport(SwiftUI) && canImport(SpriteKit)
import SwiftUI
import SpriteKit

@MainActor
struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = ArenaScene(size: CGSize(width: 600, height: 900))

    var body: some View {
        SpriteView(scene: scene)
            .background(Color.black)
            .onAppear { scene.scaleMode = .aspectFit }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { scene.pauseForBackground() }
            }
    }
}
#endif
