import Foundation

public enum TurretKind: Sendable, Equatable, CaseIterable {
    case monkeyTesla, bulldogMortar

    public var name: String {
        self == .monkeyTesla ? "Monkey Tesla Slinger" : "Bulldog Mortar Pup"
    }
    public var cost: Int { self == .monkeyTesla ? 40 : 70 }
    public var damage: Int { self == .monkeyTesla ? 9 : 30 }
    public var fireInterval: Double { self == .monkeyTesla ? 0.5 : 1.6 }
}