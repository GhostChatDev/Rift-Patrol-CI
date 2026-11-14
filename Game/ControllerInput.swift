import GameController

/// DualSense / MFi gamepad: left stick aims, R2 fires, Options pauses.
@MainActor
final class ControllerInput {
    private(set) var pad: GCExtendedGamepad?
    var sensitivity = 1.0
    var onPause: (() -> Void)?

    func start() {
        if let first = GCController.controllers().first { pad = first.extendedGamepad }
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            let extended = (note.object as? GCController)?.extendedGamepad
            MainActor.assumeIsolated { self?.pad = extended }
        }
        pad?.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { Task { @MainActor in self?.onPause?() } }
        }
    }

    func apply(to scene: ArenaScene, dt: Double) {
        guard let pad else { return }
        let x = Double(pad.leftThumbstick.xAxis.value)
        let y = Double(pad.leftThumbstick.yAxis.value)
        if abs(x) > 0.15 || abs(y) > 0.15 {
            let step = x * 2.2 * sensitivity * dt
            scene.aimAngle = min(max(scene.aimAngle - step, 0.15), Double.pi - 0.15)
        }
        if pad.rightTrigger.value > 0.3 { scene.firing = true }
        else if pad.rightTrigger.value <= 0.3, !scene.touchHeld { scene.firing = false }
    }
}
