import Foundation

public enum ComboTier: Int, Sendable, Equatable {
    case none = 0, double, triple, frenzy, god

    public init(count: Int) {
        switch count {
        case ..<2: self = .none
        case 2: self = .double
        case 3: self = .triple
        case 4: self = .frenzy
        default: self = .god
        }
    }

    public var banner: String {
        switch self {
        case .none: return ""
        case .double: return "x2 DOUBLE POP"
        case .triple: return "x3 TRIPLE BANISH"
        case .frenzy: return "x4 RIFT FRENZY"
        case .god: return "x5+ GHOST GOD"
        }
    }

    public var scrapMultiplier: Double {
        switch self {
        case .none: return 1.0
        case .double: return 1.25
        case .triple: return 1.5
        case .frenzy: return 2.0
        case .god: return 3.0
        }
    }
}

public struct ComboTracker: Sendable, Equatable {
    public static let window: Double = 3.2

    public private(set) var count = 0
    public private(set) var best = 0
    private var lastKill: Double = -.infinity

    public init() {}

    public var tier: ComboTier { ComboTier(count: count) }

    /// Hit-confirm synth pitch ratio: rises with the chain, capped.
    public var pitch: Double { 1.0 + 0.06 * Double(min(max(count - 1, 0), 8)) }

    public mutating func registerKill(at time: Double) {
        if time - lastKill <= Self.window { count += 1 } else { count = 1 }
        lastKill = time
        best = max(best, count)
    }

    /// Call every frame; resets the chain when the window runs out.
    public mutating func update(at time: Double) {
        if count > 0, time - lastKill > Self.window { count = 0 }
    }
}