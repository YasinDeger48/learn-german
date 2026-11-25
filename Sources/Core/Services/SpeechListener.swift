import AVFoundation
import Speech
import SwiftUI

/// Listens to German speech with Apple's speech recognition (on the device when it can).
/// Nothing is recorded or kept: the words are only compared with the target.
final class SpeechListener: ObservableObject {
    enum Access { case unknown, granted, denied, unavailable }

    @Published private(set) var transcript = ""
    @Published private(set) var listening = false
    @Published private(set) var access: Access = .unknown
    /// 0…1, how loud the microphone is, for the ring around the button.
    @Published private(set) var loudness: CGFloat = 0
    /// Words (SpeechScore.key) the recogniser was not sure about (confidence under 0.45 in the final result).
    @Published private(set) var unsureWords: Set<String> = []

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    /// A new engine for every listening, made after the session is set to record: an engine whose microphone input
    /// was touched while the app was only playing (the read-aloud before) has a 0-channel input and cannot listen.
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silence: DispatchWorkItem?
    private var limit: DispatchWorkItem?
    private var onFinish: ((String) -> Void)?
    /// When the microphone level was last published (audio thread only).
    private var lastLevelUpdate: TimeInterval = 0
    /// Bumped by every start, so a late stop / callback of an earlier listening is ignored.
    private var generation = 0

    init() { refreshAccess() }

    /// Reads the current permissions without asking.
    func refreshAccess() {
        guard recognizer != nil else { access = .unavailable; return }
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioSession.sharedInstance().recordPermission
        if speech == .authorized && mic == .granted {
            access = .granted
        } else if speech == .denied || speech == .restricted || mic == .denied {
            access = .denied
        } else {
            access = .unknown
        }
    }

    /// Asks for speech recognition, then microphone access.
    func requestAccess() {
        guard recognizer != nil else { access = .unavailable; return }
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { self.access = .denied }
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { self.access = granted ? .granted : .denied }
            }
        }
    }

    /// Starts listening. Stops by itself after `pause` seconds without new words, or after `maxSeconds`.
    /// Returns false when listening could not start.
    @discardableResult
    func start(hints: [String] = [], pause: TimeInterval = 1.6, maxSeconds: TimeInterval = 20,
               onFinish: @escaping (String) -> Void) -> Bool {
        if access != .granted { refreshAccess() }  // permission may have been given in Settings meanwhile
        guard access == .granted, let recognizer, recognizer.isAvailable else { return false }
        cancel()
        A1Speaker.shared.stop()
        TextAudioPlayer.shared.stop()
        transcript = ""
        unsureWords = []

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return false
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = Array(hints.prefix(100))
        // Not forced onto the device: without the German on-device model that fails at once ("unavailable");
        // iOS uses the device when it can and Apple's server otherwise. Nothing is stored by the app.
        request.requiresOnDeviceRecognition = false

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return false }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            self?.measure(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return false
        }

        generation += 1
        let current = generation
        self.engine = engine
        self.request = request
        self.onFinish = onFinish
        listening = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.generation == current, self.onFinish != nil else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    // Confidence is only filled in (above 0) for the final result.
                    self.unsureWords = Set(result.bestTranscription.segments
                        .filter { $0.confidence > 0 && $0.confidence < 0.45 }
                        .map { SpeechScore.key($0.substring) })
                    if result.isFinal { self.finish(); return }
                    self.armSilence(pause)
                } else if error != nil {
                    self.finish()
                }
            }
        }
        armSilence(pause + 3)  // a moment to start speaking
        let limit = DispatchWorkItem { [weak self] in self?.stop() }
        self.limit = limit
        DispatchQueue.main.asyncAfter(deadline: .now() + maxSeconds, execute: limit)
        return true
    }

    /// Stops listening and reports what was heard.
    func stop() {
        guard listening else { return }
        stopAudio()
        request?.endAudio()
        // The final result usually comes at once; if not, finish with what we have (only this listening).
        let current = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.generation == current else { return }
            self.finish()
        }
    }

    /// Stops without reporting.
    func cancel() {
        onFinish = nil
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func finish() {
        guard let onFinish else { return }
        self.onFinish = nil
        stopAudio()
        task?.finish()
        task = nil
        request = nil
        onFinish(transcript)
    }

    private func stopAudio() {
        silence?.cancel()
        limit?.cancel()
        if let engine {
            if engine.isRunning { engine.stop() }
            engine.inputNode.removeTap(onBus: 0)
        }
        engine = nil
        listening = false
        loudness = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func armSilence(_ seconds: TimeInterval) {
        silence?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.stop() }
        silence = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func measure(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in stride(from: 0, to: n, by: 4) { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(max(1, n / 4)))
        let level = CGFloat(min(1, max(0, (20 * log10(max(rms, 0.000_01)) + 50) / 40)))
        let now = Date().timeIntervalSince1970
        guard now - lastLevelUpdate >= 0.066 else { return }
        lastLevelUpdate = now
        DispatchQueue.main.async { self.loudness = self.loudness * 0.6 + level * 0.4 }
    }
}

// MARK: - Scoring

/// Compares what was heard with the target sentence, word by word.
enum SpeechScore {
    struct Word: Hashable {
        let text: String
        let ok: Bool
        /// Heard, but the recogniser was not sure: shown in orange and counted half.
        var unclear = false
    }

    struct Result: Hashable {
        let words: [Word]
        /// 0…100
        let score: Int
        let heard: String
    }

    /// Lower case, ß → ss, no accents or punctuation, digits as German words ("3" → "drei").
    static func key(_ word: String) -> String {
        var s = word.lowercased().replacingOccurrences(of: "ß", with: "ss")
        s = s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        s = String(String.UnicodeScalarView(s.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
        if let n = Int(s), n >= 0, n < 1_000_000 {
            s = a1GermanNumber(n).replacingOccurrences(of: "ß", with: "ss")
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        }
        return s
    }

    static func split(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "-" || $0 == "–" || $0 == "/" }).map(String.init)
    }

    /// Same word, or a long word with one letter different (the recogniser often drops an ending).
    private static func close(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard a.count >= 5, abs(a.count - b.count) <= 1 else { return false }
        return distance(Array(a), Array(b)) <= 1
    }

    private static func distance(_ a: [Character], _ b: [Character]) -> Int {
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var previous = row[0]
            row[0] = i
            for j in 1...b.count {
                let current = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] == b[j - 1] ? 0 : 1))
                previous = current
            }
        }
        return row[b.count]
    }

    /// `unsure`: keys of heard words the recogniser was not sure about (SpeechListener.unsureWords).
    static func check(target: String, heard: String, unsure: Set<String> = []) -> Result {
        let shown = split(target)
        let targetKeys = shown.map(key)
        let heardKeys = split(heard).map(key).filter { !$0.isEmpty }
        let n = targetKeys.count, m = heardKeys.count
        // Longest common subsequence, so extra or missing words do not shift everything.
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    table[i][j] = close(targetKeys[i - 1], heardKeys[j - 1])
                        ? table[i - 1][j - 1] + 1 : max(table[i - 1][j], table[i][j - 1])
                }
            }
        }
        var matched = Set<Int>()
        var unclear = Set<Int>()
        var i = n, j = m
        while i > 0 && j > 0 {
            if close(targetKeys[i - 1], heardKeys[j - 1]) && table[i][j] == table[i - 1][j - 1] + 1 {
                matched.insert(i - 1)
                if unsure.contains(heardKeys[j - 1]) { unclear.insert(i - 1) }
                i -= 1; j -= 1
            } else if table[i - 1][j] >= table[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        let counted = targetKeys.indices.filter { !targetKeys[$0].isEmpty }
        let words = shown.indices.map {
            Word(text: shown[$0], ok: targetKeys[$0].isEmpty || matched.contains($0), unclear: unclear.contains($0))
        }
        let points: Double = counted.reduce(0) { sum, k in
            sum + (matched.contains(k) ? (unclear.contains(k) ? 0.5 : 1) : 0)
        }
        let score = counted.isEmpty ? 0 : Int((points / Double(counted.count) * 100).rounded())
        return Result(words: words, score: score, heard: heard)
    }

    /// For speaking tasks: does the answer contain one of the phrases, word after word? Each word may be a
    /// little different, as the recogniser writes it: "ich heiß" / "ich heisse" count for "ich heiße", "gerne" for
    /// "gern". Very short words (up to 3 letters: "da", "vor", "bis") must match exactly.
    static func mentions(_ transcript: String, _ phrases: [String]) -> Bool {
        let heard = split(transcript).map(key).filter { !$0.isEmpty }
        return phrases.contains { phrase in
            let wanted = split(phrase).map(key).filter { !$0.isEmpty }
            guard !wanted.isEmpty, heard.count >= wanted.count else { return false }
            for start in 0...(heard.count - wanted.count) {
                if wanted.indices.allSatisfy({ sameWord(heard[start + $0], wanted[$0]) }) { return true }
            }
            return false
        }
    }

    /// One word of a phrase: exact for short words; otherwise also a longer form ("gerne") or one letter off.
    private static func sameWord(_ heard: String, _ wanted: String) -> Bool {
        if wanted.count <= 3 { return heard == wanted }
        if heard.hasPrefix(wanted) { return true }
        if wanted.count >= 5 && wanted.hasPrefix(heard) && wanted.count - heard.count <= 2 { return true }  // "heiss" for "heisse"
        return close(heard, wanted)
    }
}
