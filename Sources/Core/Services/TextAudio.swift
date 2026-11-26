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

    /// What the learner can choose (Settings, reading screen). The device voice is never offered:
    /// it only reads when there is no recording or no internet.
    static let choices: [ReadingVoice] = [.female, .male]

    /// The chosen voice; an old "device" choice counts as Anna.
    static func from(_ raw: String) -> ReadingVoice {
        let voice = ReadingVoice(rawValue: raw) ?? .female
        return voice == .device ? .female : voice
    }
}

/// Playback position of the text being read (0…1).
final class PlaybackProgress: ObservableObject {
    @Published var value: Double = 0
}

/// A thin bar that follows PlaybackProgress; the only view that redraws while a text plays.
struct PlaybackProgressBar: View {
    @ObservedObject var feed: PlaybackProgress
    var body: some View { ProgressView(value: feed.value).tint(DS.gold) }
}

/// Plays a text's recorded voice. The MP3 is downloaded the first time and kept in Caches, so it then works
/// offline. Speed changes keep the pitch.
final class TextAudioPlayer: ObservableObject {
    static let shared = TextAudioPlayer()
    static let base = URL(string: "https://yasindeger48.github.io/deschly-site/audio/")!

    @Published private(set) var playing = false
    @Published private(set) var loading = false
    /// 0…1 of the current text. In its own object: only the progress bar observes it (it changes 4 times a second
    /// and the whole reading screen used to redraw with it).
    let progressFeed = PlaybackProgress()
    var progress: Double { progressFeed.value }

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
        let token = playToken
        request = URLSession.shared.dataTask(with: remote) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                // Stopped meanwhile (the learner left the page): no playback and no fallback to the device voice.
                // Before, the cancelled download counted as a failure and the device voice read the whole text.
                guard let self, self.playToken == token else { return }
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
            self?.progressFeed.value = min(1, time.seconds / duration)
        }
        progressFeed.value = 0
        player.playImmediately(atRate: speed)
        playing = true
    }

    func setSpeed(_ speed: Float) {
        guard playing, let player else { return }
        player.rate = speed
    }

    /// Bumped by every stop, so a download that finishes after it starts nothing.
    private var playToken = 0

    /// Everything that speaks or plays: the reading voice, words and sentences, background sound.
    static func stopEverything() {
        TextAudioPlayer.shared.stop()
        A1Speaker.shared.stop()
        AmbiencePlayer.shared.stop()
    }

    func stop() {
        playToken += 1
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

    /// On by default (owner's choice 2026-11-26); the learner can turn it off on the reading screen.
    @Published var enabled: Bool = UserDefaults.standard.object(forKey: AmbiencePlayer.enabledKey) as? Bool ?? true {
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

// MARK: - Words

/// Recorded natural voice for single words ("der Bahnhof"), made by tools/word_audio.py.
/// audio/words.json maps the spoken text to a file; files are downloaded on first use and kept.
final class WordAudio {
    static let shared = WordAudio()

    private var items: [String: String] = [:]
    private var loaded = false
    private var player: AVAudioPlayer?
    private var pending: String?
    private let lock = NSLock()

    private struct File: Decodable {
        let items: [String: String]
    }

    private static var folder: URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("TextAudio")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func key(_ text: String) -> String {
        text.lowercased().split(whereSeparator: { $0 == " " || $0 == "\n" }).joined(separator: " ")
    }

    /// Reads the cached list, then refreshes it from the website once per launch.
    func load() {
        lock.lock()
        defer { lock.unlock() }
        guard !loaded else { return }
        loaded = true
        // The list is about 1 MB: decoded off the main thread, and downloaded again only when it changed
        // (ETag) and at most every 12 hours, not on every launch.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cache = Self.folder.appendingPathComponent("words.json")
            if let data = try? Data(contentsOf: cache), let file = try? JSONDecoder().decode(File.self, from: data) {
                DispatchQueue.main.async { if self?.items.isEmpty == true { self?.items = file.items } }
            }
            let defaults = UserDefaults.standard
            let fresh = Date().timeIntervalSince1970 - defaults.double(forKey: "wordAudio.checked") < 12 * 3600
            if fresh && FileManager.default.fileExists(atPath: cache.path) { return }
            var request = URLRequest(url: TextAudioPlayer.base.appendingPathComponent("words.json"))
            request.cachePolicy = .reloadIgnoringLocalCacheData
            if FileManager.default.fileExists(atPath: cache.path), let tag = defaults.string(forKey: "wordAudio.etag") {
                request.setValue(tag, forHTTPHeaderField: "If-None-Match")
            }
            URLSession.shared.dataTask(with: request) { data, response, _ in
                guard let http = response as? HTTPURLResponse else { return }
                if http.statusCode == 304 {
                    defaults.set(Date().timeIntervalSince1970, forKey: "wordAudio.checked")
                    return
                }
                guard http.statusCode == 200, let data,
                      let file = try? JSONDecoder().decode(File.self, from: data) else { return }
                try? data.write(to: cache, options: .atomic)
                defaults.set(http.value(forHTTPHeaderField: "ETag"), forKey: "wordAudio.etag")
                defaults.set(Date().timeIntervalSince1970, forKey: "wordAudio.checked")
                DispatchQueue.main.async { self?.items = file.items }
            }.resume()
        }
    }

    /// Key of a spoken line in words.json: the woman's / default voice uses the plain key,
    /// the man's lines "1|…" and the announcer's "2|…" (tools/word_audio.py).
    static func lineKey(_ line: A1Line) -> String {
        line.s == 1 || line.s == 2 ? "\(line.s)|\(key(line.t))" : key(line.t)
    }

    private static func local(_ hash: String) -> URL { folder.appendingPathComponent("w-\(hash).mp3") }

    /// Bumped by every start and stop, so an older line sequence stops going on.
    private var sequence = 0

    /// Plays recorded lines one after the other (0.5 s between lines, 2 s between rounds, like the iPhone voice did).
    /// Returns false when one of the lines has no recording; `fallback` runs when a download fails.
    func play(lines: [A1Line], slow: Bool, times: Int, fallback: @escaping () -> Void) -> Bool {
        load()
        let hashes = lines.compactMap { items[Self.lineKey($0)] }
        guard !lines.isEmpty, hashes.count == lines.count else { return false }
        stop()
        let token = sequence
        let group = DispatchGroup()
        var failed = false
        for hash in Set(hashes) where !FileManager.default.fileExists(atPath: Self.local(hash).path) {
            group.enter()
            let local = Self.local(hash)
            URLSession.shared.dataTask(with: TextAudioPlayer.base.appendingPathComponent("w/\(hash).mp3")) { data, response, _ in
                let saved = data.map { $0.count > 500 } == true && (response as? HTTPURLResponse)?.statusCode == 200
                    && (try? data?.write(to: local, options: .atomic)) != nil
                DispatchQueue.main.async {
                    if !saved { failed = true }
                    group.leave()
                }
            }.resume()
        }
        group.notify(queue: .main) { [weak self] in
            guard let self, self.sequence == token else { return }
            if failed {
                fallback()
                return
            }
            var queue: [(url: URL, gap: Double)] = []
            let rounds = max(1, times)
            for round in 0..<rounds {
                for (index, hash) in hashes.enumerated() {
                    let last = index == hashes.count - 1
                    let gap: Double = last ? (round < rounds - 1 ? 2.0 : 0) : 0.5
                    queue.append((url: Self.local(hash), gap: gap))
                }
            }
            self.playNext(queue, slow: slow, token: token)
        }
        return true
    }

    private func playNext(_ queue: [(url: URL, gap: Double)], slow: Bool, token: Int) {
        guard sequence == token, let first = queue.first else { return }
        start(first.url, slow: slow)
        let length = (player?.duration ?? 0) / (slow ? 0.7 : 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + length + first.gap) { [weak self] in
            self?.playNext(Array(queue.dropFirst()), slow: slow, token: token)
        }
    }

    /// Plays the recording of `text` if there is one.
    /// Returns false when there is none; `fallback` runs when the download fails.
    func play(_ text: String, slow: Bool, fallback: @escaping () -> Void) -> Bool {
        load()
        guard let hash = items[Self.key(text)] else { return false }
        pending = hash
        let local = Self.folder.appendingPathComponent("w-\(hash).mp3")
        if FileManager.default.fileExists(atPath: local.path) {
            start(local, slow: slow)
            return true
        }
        let remote = TextAudioPlayer.base.appendingPathComponent("w/\(hash).mp3")
        URLSession.shared.dataTask(with: remote) { [weak self] data, response, _ in
            let saved = data.map { $0.count > 500 } == true && (response as? HTTPURLResponse)?.statusCode == 200
                && (try? data?.write(to: local, options: .atomic)) != nil
            DispatchQueue.main.async {
                guard let self, self.pending == hash else { return }
                if saved { self.start(local, slow: slow) } else { fallback() }
            }
        }.resume()
        return true
    }

    private func start(_ url: URL, slow: Bool) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.enableRate = true
        player.rate = slow ? 0.7 : 1
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    func stop() {
        pending = nil
        sequence += 1
        player?.stop()
        player = nil
    }
}
