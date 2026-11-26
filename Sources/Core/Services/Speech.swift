import SwiftUI
import AVFoundation

// MARK: - Speech

final class A1Speaker {
    static let shared = A1Speaker()
    private let synth = AVSpeechSynthesizer()

    private init() {
        // The word list for the natural voice, so the first tapped word can use it.
        WordAudio.shared.load()
    }

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

    /// Words and sentences with a recorded natural voice (WordAudio, Google) play that;
    /// the device voice reads only what has no recording yet, or when there is no internet.
    func say(_ text: String, slow: Bool = false, times: Int = 1) {
        play([A1Line(s: -1, t: text)], slow: slow, times: times)
    }

    /// Plays the lines in order; `times: 2` repeats everything like in the exam.
    /// `onLine` (recorded voice only) gets the index of the line that starts and nil at the end; with the iPhone
    /// voice it gets nil at once, and the caller watches `isSpeaking`.
    func play(_ lines: [A1Line], slow: Bool = false, times: Int = 1, onLine: ((Int?) -> Void)? = nil) {
        synth.stopSpeaking(at: .immediate)
        let recorded = WordAudio.shared.play(lines: lines, slow: slow, times: times, onLine: onLine) { [weak self] in
            onLine?(nil)
            self?.speak(lines, slow: slow, times: times)
        }
        if !recorded {
            onLine?(nil)
            speak(lines, slow: slow, times: times)
        }
    }

    /// The device voice.
    private func speak(_ lines: [A1Line], slow: Bool, times: Int) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        WordAudio.shared.stop()
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
        WordAudio.shared.stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: 0).0
        utterance.rate = 0.46 * speed
        synth.speak(utterance)
    }

    /// Reads a dialogue: every speaker in an own voice and the names are not read; narration in the reading voice.
    func readDialogue(_ lines: [Dialogue.Line], speed: Float) {
        WordAudio.shared.stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        synth.stopSpeaking(at: .immediate)
        let females = germanVoices.filter { $0.gender == .female }
        let males = germanVoices.filter { $0.gender == .male }
        var assigned: [String: (AVSpeechSynthesisVoice?, Float)] = [:]
        var femaleCount = 0
        var maleCount = 0
        func speakerVoice(_ name: String) -> (AVSpeechSynthesisVoice?, Float) {
            if let known = assigned[name] { return known }
            let male = Dialogue.isMale(name)
            let n = male ? maleCount : femaleCount
            let pool = male ? males : females
            let base = voice(for: male ? 1 : 0)
            // A second speaker of the same gender: the next voice, or the same voice a bit higher.
            let chosen: (AVSpeechSynthesisVoice?, Float) = n < pool.count
                ? (pool[n], 1.0)
                : (base.0, base.1 * (1 + 0.12 * Float(n - pool.count)))
            if male { maleCount += 1 } else { femaleCount += 1 }
            assigned[name] = chosen
            return chosen
        }
        for line in lines {
            let utterance = AVSpeechUtterance(string: line.words)
            var chosen = voice(for: 0)
            if let name = line.name { chosen = speakerVoice(name) }
            let (chosenVoice, pitch) = chosen
            utterance.voice = chosenVoice
            utterance.pitchMultiplier = pitch
            utterance.rate = 0.46 * speed
            utterance.postUtteranceDelay = 0.45
            synth.speak(utterance)
        }
    }

    var isSpeaking: Bool { synth.isSpeaking }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        WordAudio.shared.stop()
    }
}

/// Dialogue texts ("Lina: Hallo!"): who says what. Same rules as dialogue_plan in tools/audio.py, which records
/// them with one voice per speaker; "Sie sagt: …" and "Der Mann antwortet: …" are narration, not speakers.
enum Dialogue {
    struct Line {
        let name: String?  // nil = narration
        let words: String
    }

    private static let notAName: Set<String> = ["Der", "Die", "Das", "Ein", "Eine", "Sie", "Er", "Es", "Ich", "Wir", "Aber", "Und", "Dann"]
    private static let male: Set<String> = [
        "Tom", "Max", "Ben", "Paul", "Jan", "Lukas", "Felix", "Leon", "David", "Ali", "Mehmet", "Ahmet", "Murat",
        "Emre", "Peter", "Thomas", "Michael", "Stefan", "Jonas", "Mann", "Kellner", "Arzt", "Lehrer", "Verkäufer",
        "Chef", "Vater", "Opa", "Junge", "Polizist", "Fahrer", "Nachbar", "Kollege", "Freund", "Busfahrer",
    ]

    /// The speaker and the words of one paragraph, or nil when it is not a dialogue line.
    static func speaker(_ paragraph: String) -> Line? {
        let text = paragraph.trimmingCharacters(in: .whitespaces)
        guard let colon = text.range(of: ": ") else { return nil }
        let name = String(text[..<colon.lowerBound])
        let words = text[colon.upperBound...].trimmingCharacters(in: .whitespaces)
        let parts = name.split(separator: " ")
        guard (1...2).contains(parts.count), !words.isEmpty, !notAName.contains(String(parts[0])),
              parts.allSatisfy({ part in
                  part.count > 1 && part.first?.isUppercase == true && part.dropFirst().allSatisfy { $0.isLowercase }
              }) else { return nil }
        return Line(name: name, words: words)
    }

    static func isMale(_ name: String) -> Bool {
        name.hasPrefix("Herr ") || male.contains(String(name.split(separator: " ").first ?? ""))
    }

    /// The lines of a dialogue text, or nil when fewer than two paragraphs have a speaker.
    static func lines(_ paragraphs: [String]) -> [Line]? {
        let lines = paragraphs.map { speaker($0) ?? Line(name: nil, words: $0) }
        return lines.filter { $0.name != nil }.count >= 2 ? lines : nil
    }
}

extension View {
    /// The whole row reads `text` aloud, not only the small speaker icon on it. The buttons on the row
    /// (A1SpeakButton, the slow one) keep their own taps. VoiceOver users keep using those buttons.
    func speaksOnTap(_ text: String, slow: Bool = false) -> some View {
        contentShape(Rectangle()).onTapGesture { A1Speaker.shared.say(text, slow: slow) }
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
