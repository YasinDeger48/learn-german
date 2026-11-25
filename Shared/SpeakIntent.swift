import AppIntents
import AVFoundation
import Foundation

// "Listen" on the widgets. Compiled into the app AND the widget extension: an AudioPlaybackIntent is run by
// iOS in the app's process (woken in the background), because a widget extension may not play sound itself.
// The app declares the "audio" background mode for this.

/// "Listen": speaks German text without opening the app (iOS 17 audio intent).
@available(iOS 17.0, *)
struct SpeakIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Listen"

    @Parameter(title: "Text")
    var text: String

    init() {}

    init(text: String) {
        self.text = text
    }

    func perform() async throws -> some IntentResult {
        await WidgetSpeaker.shared.speak(text)
        return .result()
    }
}

@available(iOS 17.0, *)
@MainActor
final class WidgetSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = WidgetSpeaker()
    private let synthesizer = AVSpeechSynthesizer()
    private var waiting: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks and returns when done (at most ~8 s), so the intent keeps running while it talks.
    func speak(_ text: String) async {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        finish()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = 0.45
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiting = continuation
            synthesizer.speak(utterance)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                self.finish()
            }
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func finish() {
        waiting?.resume()
        waiting = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}
