import AVFoundation
import SwiftUI

/// Who reads the daily texts: two recorded natural voices (made with tools/audio.py, kept on the website)
/// or the iPhone's own voice.
enum ReadingVoice: String, CaseIterable, Identifiable {
    case female, male, device

    var id: String { rawValue }
    var title: String { t("voice.\(rawValue)") }
    var subtitle: String { t("voice.\(rawValue).sub") }
    var icon: String { self == .device ? "iphone" : "waveform" }
    /// Folder on the website; nil for the iPhone voice.
    var folder: String? {
        switch self {
        case .female: return "f"
        case .male: return "m"
        case .device: return nil
        }
    }

    static let storageKey = "readingVoice"
}

/// Plays a text's recorded voice. The MP3 is downloaded the first time and kept in Caches, so it then works
/// offline. Speed changes keep the pitch.
final class TextAudioPlayer: ObservableObject {
    static let shared = TextAudioPlayer()
    static let base = URL(string: "https://yasindeger48.github.io/deschly-site/audio/")!

    @Published private(set) var playing = false
    @Published private(set) var loading = false
    /// 0…1 of the current text.
    @Published private(set) var progress: Double = 0

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var request: URLSessionDataTask?

    private static var folder: URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("TextAudio")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func localURL(_ id: String, _ folder: String) -> URL {
        Self.folder.appendingPathComponent("\(folder)-\(id).mp3")
    }

    /// Starts the recorded voice. Calls `failed` (on the main thread) when there is no recording or no internet,
    /// so the caller can read with the iPhone voice instead.
    func play(textID: String, voice: ReadingVoice, speed: Float, failed: @escaping () -> Void) {
        stop()
        guard let folder = voice.folder else { failed(); return }
        let local = Self.localURL(textID, folder)
        if FileManager.default.fileExists(atPath: local.path) {
            start(local, speed: speed)
            return
        }
        loading = true
        let remote = Self.base.appendingPathComponent(folder).appendingPathComponent("\(textID).mp3")
        request = URLSession.shared.dataTask(with: remote) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.loading = false
                guard let data, data.count > 1000, (response as? HTTPURLResponse)?.statusCode == 200,
                      (try? data.write(to: local, options: .atomic)) != nil else {
                    failed()
                    return
                }
                self.start(local, speed: speed)
            }
        }
        request?.resume()
    }

    private func start(_ url: URL, speed: Float) {
        A1Speaker.shared.stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .timeDomain
        let player = AVPlayer(playerItem: item)
        self.player = player
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.finish()
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 else { return }
            self?.progress = min(1, time.seconds / duration)
        }
        progress = 0
        player.playImmediately(atRate: speed)
        playing = true
    }

    func setSpeed(_ speed: Float) {
        guard playing, let player else { return }
        player.rate = speed
    }

    func stop() {
        request?.cancel()
        request = nil
        loading = false
        finish()
    }

    private func finish() {
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
        playing = false
    }
}
