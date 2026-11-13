# Rift Patrol

A small arcade base-defense game for **macOS 14+ and iOS 17+**, built with Swift 6, SwiftUI and SpriteKit. Defend your van through five waves: click or tap ghosts to shoot, earn scrap for kills and combos, and buy up to four automated Tesla or mortar turrets. Ghosts reaching the van deal damage. Clear wave five to win; restart at any time.

## Run on a Mac

Install Xcode with the Swift 6 toolchain, open Terminal in this repository and run:

```sh
swift run RiftPatrolGame
```

Click ghosts repeatedly to damage them. Use the bottom buttons to buy turrets, pause, or restart. You can also open `Package.swift` in Xcode, select the **RiftPatrolGame** scheme and press Run.

## Run on iPhone or iPad

1. In Xcode, create a new **iOS App** project with SwiftUI and Swift, outside this repository. Choose an iOS 17 or later deployment target.
2. Add this repository as a local package using **File → Add Package Dependencies → Add Local**, then add the **RiftPatrolCore** library to your app target.
3. Delete the new project's generated app entry-point and content view files from the target. Drag the three Swift files in this repository's `Game` folder into the project and select your app target under **Add to targets**.
4. Select an iOS simulator or a signed device and press Run. No special permissions, Info.plist keys, or capabilities are needed for the game.

## Tests and simulation

```sh
swift test
swift run RiftPatrolSim 20
```

The simulation and core tests run without SpriteKit. The playable game requires an Apple platform; on Linux its executable prints a platform requirement instead.
