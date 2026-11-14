#if canImport(SwiftUI) && canImport(SpriteKit)
import SwiftUI

@main
struct RiftPatrolGameApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .frame(minWidth: 320, minHeight: 500)
        }
    }
}
#else
@main
struct RiftPatrolGameApp {
    static func main() {
        print("Rift Patrol Game requires macOS 14 or iOS 17 and SpriteKit.")
    }
}
#endif
