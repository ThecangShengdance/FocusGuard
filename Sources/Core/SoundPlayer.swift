import AppKit
import AVFoundation

enum SoundPlayer {
    static func play(_ name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            NSSound.beep()
            return
        }
        sound.stop()
        sound.play()
    }

    static func phaseFinished() { play("Glass") }
    static func breakFinished() { play("Ping") }
    static func distraction() { play("Sosumi") }
    static func tick() { play("Tink") }
}

final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
