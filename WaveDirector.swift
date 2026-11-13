import Foundation

public struct WaveSpec: Sendable, Equatable {
    public let count: Int
    public let hp: Int
    public let shield: Int
    public let speed: Double
    public let spawnInterval: Double
}

/// Difficulty curve: more, tougher, faster ghosts each wave.
public enum WaveDirector {
    public static func spec(forWave wave: Int) -> WaveSpec {
        let w = max(1, wave)
        return WaveSpec(
            count: 6 + 3 * w,
            hp: 30 + 12 * w,
            shield: w >= 2 ? 10 * (w - 1) : 0,
            speed: 6 + 0.8 * Double(w),
            spawnInterval: max(0.6, 1.6 - 0.1 * Double(w))
        )
    }
}