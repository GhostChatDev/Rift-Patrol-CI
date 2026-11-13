#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Short synthesized effects; no downloaded assets or permissions required.
@MainActor
final class ArcadeAudio {
    enum Cue { case shot, banish, power, hurt }
    private var players: [AVAudioPlayer] = []
    private var cache: [Int: Data] = [:]

    func play(_ cue: Cue) {
        let key: Int
        let frequency: Double
        let duration: Double
        switch cue {
        case .shot: key = 0; frequency = 740; duration = 0.045
        case .banish: key = 1; frequency = 480; duration = 0.12
        case .power: key = 2; frequency = 960; duration = 0.22
        case .hurt: key = 3; frequency = 110; duration = 0.18
        }
        let data: Data
        if let existing = cache[key] { data = existing } else {
            data = ToneWave.make(frequency: frequency, duration: duration)
            cache[key] = data
        }
        players.removeAll { !$0.isPlaying }
        guard players.count < 8, let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = 0.18
        players.append(player)
        player.play()
    }
}
#endif

import Foundation

enum ToneWave {
    static func make(frequency: Double, duration: Double) -> Data {
        let rate = 22050
        let count = max(1, Int(Double(rate) * duration))
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) {
            data.append(UInt8(value & 255))
            data.append(UInt8((value >> 8) & 255))
        }
        func u32(_ value: UInt32) {
            u16(UInt16(value & 65535))
            u16(UInt16((value >> 16) & 65535))
        }
        text("RIFF"); u32(UInt32(36 + count * 2)); text("WAVEfmt ")
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2))
        u16(2); u16(16); text("data"); u32(UInt32(count * 2))
        for index in 0..<count {
            let t = Double(index) / Double(rate)
            let progress = Double(index) / Double(count)
            let envelope = min(1, t * 500) * (1 - progress)
            let sample = Int16(sin(2 * .pi * frequency * t * (1 - progress * 0.3)) * envelope * 14000)
            u16(UInt16(bitPattern: sample))
        }
        return data
    }
}
