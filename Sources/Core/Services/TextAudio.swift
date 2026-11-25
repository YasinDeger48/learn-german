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

// MARK: - Background sound

/// A quiet loop under the reading voice (bus, café, office…), chosen per text by tools/ambience.py.
/// audio/ambience.json and the loops come from the website and are kept in Caches.
final class AmbiencePlayer: ObservableObject {
    static let shared = AmbiencePlayer()
    private static let enabledKey = "ambienceOn"
    private static let volume: Float = 0.22

    @Published var enabled: Bool = UserDefaults.standard.bool(forKey: AmbiencePlayer.enabledKey) {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }
    }
    /// Text id → kind ("bus", "cafe", …).
    @Published private(set) var kinds: [String: String] = [:]

    private var player: AVAudioPlayer?
    private var loaded = false
    private var wanted: String?

    private struct File: Decodable {
        let texts: [String: String]
    }

    private static var folder: URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("TextAudio")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Reads the cached list at once, then refreshes it from the website (once per launch).
    func load() {
        guard !loaded else { return }
        loaded = true
        let cache = Self.folder.appendingPathComponent("ambience.json")
        if let data = try? Data(contentsOf: cache), let file = try? JSONDecoder().decode(File.self, from: data) {
            kinds = file.texts
        }
        let url = TextAudioPlayer.base.appendingPathComponent("ambience.json")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let data, (response as? HTTPURLResponse)?.statusCode == 200,
                  let file = try? JSONDecoder().decode(File.self, from: data) else { return }
            try? data.write(to: cache, options: .atomic)
            DispatchQueue.main.async { self?.kinds = file.texts }
        }.resume()
    }

    func kind(for textID: String) -> String? { kinds[textID] }

    /// Starts the text's loop if the learner turned background sound on.
    func start(textID: String) {
        stop()
        guard enabled, let kind = kinds[textID] else { return }
        wanted = textID
        let local = Self.folder.appendingPathComponent("amb-\(kind).m4a")
        if FileManager.default.fileExists(atPath: local.path) {
            play(local)
            return
        }
        let remote = TextAudioPlayer.base.appendingPathComponent("ambience/\(kind).m4a")
        URLSession.shared.dataTask(with: remote) { [weak self] data, response, _ in
            guard let data, data.count > 1000, (response as? HTTPURLResponse)?.statusCode == 200,
                  (try? data.write(to: local, options: .atomic)) != nil else { return }
            DispatchQueue.main.async {
                guard let self, self.wanted == textID else { return }
                self.play(local)
            }
        }.resume()
    }

    private func play(_ url: URL) {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        player.setVolume(Self.volume, fadeDuration: 1.5)
        self.player = player
    }

    func stop() {
        wanted = nil
        guard let player else { return }
        self.player = nil
        player.setVolume(0, fadeDuration: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { player.stop() }
    }
}
