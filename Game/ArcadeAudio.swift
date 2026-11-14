import AVFoundation

enum SoundCue: CaseIterable {
    case shot, banish, power, hurt, wave

    /// (start frequency Hz, end frequency Hz, seconds)
    fileprivate var tone: (Double, Double, Double) {
        switch self {
        case .shot: return (880, 440, 0.07)
        case .banish: return (300, 900, 0.16)
        case .power: return (500, 1200, 0.25)
        case .hurt: return (220, 80, 0.3)
        case .wave: return (400, 800, 0.4)
        }
    }
}

/// Small synthesized sound effects. No audio files needed.
@MainActor
final class ArcadeAudio {
    var volume: Float = 0.6
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
    private var buffers: [SoundCue: AVAudioPCMBuffer] = [:]
    private var ready = false

    init() {
        guard let format else { return }
        for cue in SoundCue.allCases {
            buffers[cue] = Self.makeBuffer(cue.tone, format: format)
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            ready = true
        } catch {
            ready = false
        }
    }

    func play(_ cue: SoundCue) {
        guard ready, volume > 0, let buffer = buffers[cue] else { return }
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private static func makeBuffer(_ tone: (Double, Double, Double), format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let count = AVAudioFrameCount(rate * tone.2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = count
        var phase = 0.0
        for i in 0..<Int(count) {
            let t = Double(i) / Double(count)
            let freq = tone.0 + (tone.1 - tone.0) * t
            phase += 2 * Double.pi * freq / rate
            data[i] = Float(sin(phase) * (1 - t) * 0.4)
        }
        return buffer
    }
}
