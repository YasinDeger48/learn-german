import CryptoKit
import Foundation

/// Content files (level JSON, daily texts, cover pictures) can be updated from the website without an App Store
/// release. Downloaded files live in Application Support/Content and replace the bundled ones from the next launch.
///
/// Website layout (written by tools/publish_content.py):
///     content/manifest.json      {"schema": 2, "files": {"a1.json": {"sha256": "…", "size": 123}, "covers/a1-001.jpg": {…}}}
///     content/a1.json, content/daily_a1.json, …, content/covers/a1-001.jpg
enum ContentStore {
    /// The manifest format this app understands. Bump it (here and in publish_content.py) when the JSON shape changes
    /// in a way older apps cannot read.
    static let schema = 2

    static var baseURL: URL {
        if let text = Bundle.main.object(forInfoDictionaryKey: "DeschlyContentURL") as? String, let url = URL(string: text) {
            return url
        }
        return URL(string: "https://yasindeger48.github.io/deschly-site/content/")!
    }

    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = base.appendingPathComponent("Content", isDirectory: true)
        // Apple's storage rule: content that can be downloaded again must not go into iCloud backups.
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }()

    /// A downloaded copy of a content file ("a1.json", "covers/a1-001.jpg"), if there is one.
    static func cached(_ name: String) -> URL? {
        let url = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The bundled copy of a content file.
    static func bundled(_ name: String) -> URL? {
        let file = (name as NSString).lastPathComponent
        return Bundle.main.url(forResource: (file as NSString).deletingPathExtension,
                               withExtension: (file as NSString).pathExtension)
    }

    /// Downloaded copy first, then the app bundle.
    static func url(_ name: String) -> URL? { cached(name) ?? bundled(name) }

    static var appBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") + "/" +
            (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
    }

    /// Broken downloaded content must not lock the app in a crash loop until the next release: if the app ended
    /// within 10 seconds of starting twice in a row while downloads are in use, they are dropped and the bundled
    /// files are used again. Call at launch, before any content is read.
    static func guardAgainstCrashLoop() {
        let key = "contentEarlyExits"
        let defaults = UserDefaults.standard
        let hasDownloads = (defaults.dictionary(forKey: ContentUpdater.installedKey) ?? [:]).isEmpty == false
        let early = defaults.integer(forKey: key)
        if hasDownloads && early >= 2 {
            try? FileManager.default.removeItem(at: folder)
            defaults.removeObject(forKey: ContentUpdater.installedKey)
            defaults.set(0, forKey: key)
            return
        }
        defaults.set(early + 1, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { defaults.set(0, forKey: key) }
    }

    /// A new app version brings newer bundled files: drop downloads made by an older version.
    static func clearIfAppChanged() {
        let key = "contentCacheBuild"
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: key) != appBuild else { return }
        try? FileManager.default.removeItem(at: folder)
        defaults.removeObject(forKey: ContentUpdater.installedKey)
        defaults.set(appBuild, forKey: key)
    }
}

struct ContentManifest: Decodable {
    struct File: Decodable {
        let sha256: String
        let size: Int
    }
    let schema: Int
    let files: [String: File]
}

/// Checks the website for new content at most every few hours, in the background.
final class ContentUpdater {
    static let shared = ContentUpdater()
    static let installedKey = "contentInstalled"
    private let lastCheckKey = "contentLastCheck"
    private let interval: TimeInterval = 6 * 60 * 60
    private var running = false
    private let queue = DispatchQueue(label: "content-updater", qos: .utility)

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        config.allowsExpensiveNetworkAccess = true
        return URLSession(configuration: config)
    }()

    func checkIfDue() {
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: lastCheckKey)
        guard !running, Date().timeIntervalSince1970 - last > interval else { return }
        running = true
        Task.detached(priority: .utility) { [self] in
            let ok = await update()
            await MainActor.run {
                if ok { UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: self.lastCheckKey) }
                self.running = false
            }
        }
    }

    /// Returns true when the check finished (with or without new files).
    private func update() async -> Bool {
        let manifestURL = ContentStore.baseURL.appendingPathComponent("manifest.json")
        guard let (data, response) = try? await session.data(from: manifestURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let manifest = try? JSONDecoder().decode(ContentManifest.self, from: data) else { return false }
        guard manifest.schema == ContentStore.schema else { return true }  // made for another app version

        var installed = UserDefaults.standard.dictionary(forKey: Self.installedKey) as? [String: String] ?? [:]
        let fm = FileManager.default
        try? fm.createDirectory(at: ContentStore.folder, withIntermediateDirectories: true)
        var downloaded = 0

        for (name, file) in manifest.files.sorted(by: { $0.key < $1.key }).prefix(Self.maxFiles) {
            guard Self.isSafe(name), file.size > 0, file.size <= Self.maxSize(name) else { continue }
            if installed[name] == file.sha256, ContentStore.cached(name) != nil { continue }
            // Same as the bundled file: no download, and a stale download is removed.
            if let bundled = ContentStore.bundled(name), Self.sha256(of: bundled) == file.sha256 {
                if let cached = ContentStore.cached(name) { try? fm.removeItem(at: cached) }
                installed[name] = nil
                continue
            }
            guard downloaded + file.size <= Self.maxPerCheck else { break }  // the rest waits for the next check
            guard let (body, reply) = try? await session.data(from: ContentStore.baseURL.appendingPathComponent(name)),
                  (reply as? HTTPURLResponse)?.statusCode == 200,
                  body.count == file.size,
                  Self.sha256(body) == file.sha256 else { continue }
            downloaded += body.count
            // A JSON file must at least be valid JSON before it replaces the bundled one.
            if name.hasSuffix(".json"), (try? JSONSerialization.jsonObject(with: body)) == nil { continue }
            let dest = ContentStore.folder.appendingPathComponent(name)
            try? fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? body.write(to: dest, options: .atomic)) != nil {
                installed[name] = file.sha256
            }
        }
        UserDefaults.standard.set(installed, forKey: Self.installedKey)
        return true
    }

    /// Limits, so a wrong or hostile manifest cannot fill the phone: files, size per file, size per check.
    static let maxFiles = 3000
    static let maxPerCheck = 120 * 1024 * 1024
    static func maxSize(_ name: String) -> Int { name.hasSuffix(".json") ? 12 * 1024 * 1024 : 4 * 1024 * 1024 }

    /// Only plain relative names like "a1.json" or "covers/a1-001.jpg".
    static func isSafe(_ name: String) -> Bool {
        name.range(of: #"^(covers/)?[a-z0-9_\-]+\.(json|jpg)$"#, options: .regularExpression) != nil
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(of url: URL) -> String? {
        (try? Data(contentsOf: url, options: .mappedIfSafe)).map { sha256($0) }
    }
}
