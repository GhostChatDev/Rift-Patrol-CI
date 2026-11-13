import Foundation

public enum HitKind: Sendable, Equatable {
    case normal, critical, shieldCrack, finisher
}

/// What one hit did, plus how the arcade popup should look.
public struct HitOutcome: Sendable, Equatable {
    public let kind: HitKind
    public let dealt: Int

    public init(kind: HitKind, dealt: Int) {
        self.kind = kind
        self.dealt = dealt
    }

    public var popupText: String {
        switch kind {
        case .normal: return "\(dealt)"
        case .critical: return "CRIT! \(dealt)"
        case .shieldCrack: return "ECTO-CRACK!"
        case .finisher: return "BANISHED! \(dealt)"
        }
    }

    public var scale: Double {
        switch kind {
        case .normal, .shieldCrack: return 1.0
        case .critical: return 1.65
        case .finisher: return 2.0
        }
    }

    public var tiltDegrees: Double { kind == .critical ? 12 : 0 }

    /// 40 ms micro hit-stop on finishers only.
    public var hitStopSeconds: Double { kind == .finisher ? 0.04 : 0 }
}