import Foundation
import Observation

enum RiftDifficulty: String, Codable, CaseIterable, Sendable {
    case easy, normal, hard
    var title: String { rawValue.capitalized }
    var enemyHealthScale: Double { self == .easy ? 0.8 : (self == .normal ? 1.0 : 1.35) }
    var damageTakenScale: Double { self == .easy ? 0.7 : (self == .normal ? 1.0 : 1.4) }
}

enum TouchLayout: String, Codable, CaseIterable, Sendable {
    case rightHanded, leftHanded
    var title: String { self == .rightHanded ? "Right-handed" : "Left-handed" }
}

struct GameSettings: Codable, Equatable, Sendable {
    var musicVolume = 0.6
    var sfxVolume = 0.8
    var hapticsEnabled = true
    var controllerSensitivity = 1.0
    var aimAssist = 0.5
    var touchLayout = TouchLayout.rightHanded
    var difficulty = RiftDifficulty.normal
    var screenShake = true

    func clamped() -> GameSettings {
        var s = self
        s.musicVolume = min(max(musicVolume, 0), 1)
        s.sfxVolume = min(max(sfxVolume, 0), 1)
        s.controllerSensitivity = min(max(controllerSensitivity, 0.5), 2)
        s.aimAssist = min(max(aimAssist, 0), 1)
        return s
    }
}

struct GameProgress: Codable, Equatable, Sendable {
    var unlockedLevel = 1
    var bestScores: [Int: Int] = [:]

    mutating func record(level: Int, score: Int, won: Bool, totalLevels: Int) {
        if score > (bestScores[level] ?? 0) { bestScores[level] = score }
        if won { unlockedLevel = min(max(unlockedLevel, level + 1), totalLevels) }
    }
    func best(for level: Int) -> Int { bestScores[level] ?? 0 }
}

@MainActor @Observable
final class SettingsStore {
    static let settingsKey = "riftpatrol.settings.v1"
    static let progressKey = "riftpatrol.progress.v1"

    var settings: GameSettings { didSet { save() } }
    private(set) var progress: GameProgress
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let d = defaults.data(forKey: Self.settingsKey),
           let s = try? JSONDecoder().decode(GameSettings.self, from: d) {
            settings = s.clamped()
        } else {
            settings = GameSettings()
        }
        if let d = defaults.data(forKey: Self.progressKey),
           let p = try? JSONDecoder().decode(GameProgress.self, from: d) {
            progress = p
        } else {
            progress = GameProgress()
        }
    }

    func recordResult(level: Int, score: Int, won: Bool, totalLevels: Int = 10) {
        progress.record(level: level, score: score, won: won, totalLevels: totalLevels)
        saveProgress()
    }

    func resetProgress() { progress = GameProgress(); saveProgress() }
    func resetSettings() { settings = GameSettings() }

    private func save() {
        if let d = try? JSONEncoder().encode(settings.clamped()) { defaults.set(d, forKey: Self.settingsKey) }
    }
    private func saveProgress() {
        if let d = try? JSONEncoder().encode(progress) { defaults.set(d, forKey: Self.progressKey) }
    }
}
