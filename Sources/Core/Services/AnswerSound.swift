import AVFoundation
import UIKit

/// Feedback after an answer: a very soft right / wrong sound (Settings → Answer sounds) and a vibration
/// on a wrong answer (Settings → Vibrate on wrong answers); both on by default.
/// The sounds are made in code (two short sine notes that fade out), so there are no audio files.
enum AnswerSound {
    static let storageKey = "answerSounds"
    static let vibrateKey = "wrongVibration"
    /// Settings → Vibrate on right answers (the owner asked for a way to turn it off, 2026-11-26).
    static let rightVibrateKey = "rightVibration"
    static var isOn: Bool { UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true }
    static var vibrates: Bool { UserDefaults.standard.object(forKey: vibrateKey) as? Bool ?? true }
    static var vibratesOnRight: Bool { UserDefaults.standard.object(forKey: rightVibrateKey) as? Bool ?? true }

    private static var player: AVAudioPlayer?
    /// A soft rising "ding-ding" and a low falling "dum-dum".
    private static let right = wav([(880, 0.07), (1318.5, 0.16)])
    private static let wrong = wav([(311.1, 0.09), (233.1, 0.18)])

    static func play(correct: Bool) {
        if correct {
            if vibratesOnRight { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        } else if vibrates {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        guard isOn else { return }
        let session = AVAudioSession.sharedInstance()
        // Respect the silent switch, unless spoken audio already set the playback category.
        if session.category != .playback {
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
        }
        player?.stop()
        player = try? AVAudioPlayer(data: correct ? right : wrong)
        player?.volume = 0.25
        player?.play()
    }

    /// 16-bit mono WAV of the notes (frequency in Hz, length in seconds), each with a quick fade in and a soft fade out.
    private static func wav(_ notes: [(Double, Double)]) -> Data {
        let rate = 44_100.0
        var samples: [Int16] = []
        for (frequency, length) in notes {
            let count = Int(rate * length)
            for i in 0..<count {
                let time = Double(i) / rate
                let attack = min(1, time / 0.006)
                let decay = exp(-time * 5 / length)
                let value = sin(2 * Double.pi * frequency * time) * attack * decay * 0.6
                samples.append(Int16(value * Double(Int16.max)))
            }
        }
        var data = Data()
        func add<T>(_ value: T) { withUnsafeBytes(of: value) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        add(UInt32(36 + bytes).littleEndian)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        add(UInt32(16).littleEndian)
        add(UInt16(1).littleEndian)       // PCM
        add(UInt16(1).littleEndian)       // mono
        add(UInt32(44_100).littleEndian)  // sample rate
        add(UInt32(88_200).littleEndian)  // bytes per second
        add(UInt16(2).littleEndian)       // block align
        add(UInt16(16).littleEndian)      // bits per sample
        data.append(contentsOf: Array("data".utf8))
        add(bytes.littleEndian)
        for sample in samples { add(sample.littleEndian) }
        return data
    }
}
