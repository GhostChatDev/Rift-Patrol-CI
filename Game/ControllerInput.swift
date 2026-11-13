#if canImport(GameController)
import Foundation
import CoreGraphics
import GameController

/// Reads a PS5 DualSense (or any MFi / Xbox / Switch pad) once per frame.
///
/// Poll-based on purpose: `GCController.current` is checked every frame, so there are
/// no notification observers, no sendable closures and no background threads.
/// Works on iOS 17+, iPadOS 17+ and macOS 14+ (Apple's GameController framework).
@MainActor
final class ControllerInput {
    /// One frame of pad state.
    struct Snapshot {
        var isConnected = false
        var name = ""
        /// Left stick, each axis in -1...1.
        var aim = CGPoint.zero
        /// Continuous: true while R2 (or A) is held.
        var firing = false
        /// Edge-triggered: true only on the frame the button goes down.
        var pulse = false
        var tesla = false
        var mortar = false
        /// Options / Menu: pause and resume.
        var menu = false
        /// A / Cross: confirm on the title, pause and result screens.
        var confirm = false
        /// Seconds since the previous frame, clamped to 0...0.05.
        var dt = 0.0
    }

    private var lastTime: TimeInterval = 0
    private var previousMask = 0

    private static let pulseBit = 1 << 0
    private static let teslaBit = 1 << 1
    private static let mortarBit = 1 << 2
    private static let menuBit = 1 << 3
    private static let confirmBit = 1 << 4

    var isConnected: Bool { Self.pad() != nil }

    private static func pad() -> GCExtendedGamepad? {
        if let current = GCController.current, let pad = current.extendedGamepad { return pad }
        for controller in GCController.controllers() {
            if let pad = controller.extendedGamepad { return pad }
        }
        return nil
    }

    private static func padName() -> String {
        if let current = GCController.current, current.extendedGamepad != nil {
            return current.vendorName ?? "GAME PAD"
        }
        for controller in GCController.controllers() where controller.extendedGamepad != nil {
            return controller.vendorName ?? "GAME PAD"
        }
        return ""
    }

    /// Call once per frame. Returns the current pad state.
    func poll(now: TimeInterval = Date.timeIntervalSinceReferenceDate) -> Snapshot {
        var state = Snapshot()
        let dt = lastTime == 0 ? 0 : min(0.05, max(0, now - lastTime))
        lastTime = now
        state.dt = dt

        guard let pad = Self.pad() else {
            previousMask = 0
            return state
        }
        state.isConnected = true
        state.name = Self.padName()

        state.aim = CGPoint(x: CGFloat(pad.leftThumbstick.xAxis.value),
                            y: CGFloat(pad.leftThumbstick.yAxis.value))

        // Analog trigger where available, digital A otherwise.
        let trigger = max(CGFloat(pad.rightTrigger.value), pad.buttonA.isPressed ? 1 : 0)
        if trigger > 0.2 { state.firing = true }

        var mask = 0
        if pad.buttonX.isPressed { mask |= Self.pulseBit }
        if pad.leftShoulder.isPressed { mask |= Self.teslaBit }
        if pad.rightShoulder.isPressed { mask |= Self.mortarBit }
        if pad.buttonOptions.isPressed || pad.buttonMenu.isPressed { mask |= Self.menuBit }
        if pad.buttonA.isPressed { mask |= Self.confirmBit }

        state.pulse = mask & Self.pulseBit != 0 && previousMask & Self.pulseBit == 0
        state.tesla = mask & Self.teslaBit != 0 && previousMask & Self.teslaBit == 0
        state.mortar = mask & Self.mortarBit != 0 && previousMask & Self.mortarBit == 0
        state.menu = mask & Self.menuBit != 0 && previousMask & Self.menuBit == 0
        state.confirm = mask & Self.confirmBit != 0 && previousMask & Self.confirmBit == 0
        previousMask = mask
        return state
    }
}
#endif
