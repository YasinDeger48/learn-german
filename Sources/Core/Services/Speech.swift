import SwiftUI
import AVFoundation

// MARK: - Speech

final class A1Speaker {
    static let shared = A1Speaker()
    private let synth = AVSpeechSynthesizer()

    /// German voices, best quality first (enhanced/premium voices if the user downloaded them).
    private lazy var germanVoices: [AVSpeechSynthesisVoice] = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("de") }
        .sorted { $0.quality.rawValue > $1.quality.rawValue }

    /// Speaker -1 = default voice, 0 = woman, 1 = man, 2 = announcer.
    /// Without a second voice on the device, the pitch tells the speakers apart.
    private func voice(for speaker: Int) -> (AVSpeechSynthesisVoice?, Float) {
        let fallback = AVSpeechSynthesisVoice(language: "de-DE")
        let female = germanVoices.first { $0.gender == .female }
        let male = germanVoices.first { $0.gender == .male }
        switch speaker {
        case 0:
            if let female { return (female, 1.0) }
            return (fallback, 1.15)
        case 1:
            if let male { return (male, 1.0) }
            return (fallback, 0.8)
        case 2:
            if let male { return (male, 0.9) }
            return (fallback, 0.7)
        default:
            return (fallback, 1.0)
        }
    }

    func say(_ text: String, slow: Bool = false, times: Int = 1) {
        play([A1Line(s: -1, t: text)], slow: slow, times: times)
    }

    /// Plays the lines in order; `times: 2` repeats everything like in the exam.
    func play(_ lines: [A1Line], slow: Bool = false, times: Int = 1) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        for round in 0..<max(1, times) {
            for (index, line) in lines.enumerated() {
                let utterance = AVSpeechUtterance(string: line.t)
                let (chosenVoice, pitch) = voice(for: line.s)
                utterance.voice = chosenVoice
                utterance.pitchMultiplier = pitch
                utterance.rate = slow ? 0.32 : 0.46
                let lastLine = index == lines.count - 1
                utterance.postUtteranceDelay = lastLine ? (round < times - 1 ? 2.0 : 0) : 0.5
                synth.speak(utterance)
            }
        }
    }

    /// Reads a longer text at a chosen speed (1.0 = normal, 0.8, 0.6).
    func read(_ text: String, speed: Float) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: 0).0
        utterance.rate = 0.46 * speed
        synth.speak(utterance)
    }

    var isSpeaking: Bool { synth.isSpeaking }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }
}

struct A1SpeakButton: View {
    let text: String
    var slow = false

    var body: some View {
        Button {
            A1Speaker.shared.say(text, slow: slow)
        } label: {
            Image(systemName: slow ? "tortoise.fill" : "speaker.wave.2.fill")
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(slow ? t("common.listenSlow") : t("common.listen"))
    }
}

func a1ArticleColor(_ type: String) -> Color {
    switch type {
    case "der": return DS.der
    case "die": return DS.die
    case "das": return DS.das
    case "pl": return DS.die
    default: return DS.ink
    }
}
