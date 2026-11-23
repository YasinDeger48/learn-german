import SwiftUI
import UniformTypeIdentifiers

/// Video lesson marks stored in UserDefaults (keys kept from the first app version).
enum LessonStore {
    static let watchedKey = "watchedLessons"
    static let favoritesKey = "favoriteLessons"
    static let notesKey = "lessonNotes"

    static func decode<T: Decodable>(_ data: Data) -> T? { try? JSONDecoder().decode(T.self, from: data) }
    static func encode<T: Encodable>(_ value: T) -> Data { (try? JSONEncoder().encode(value)) ?? Data() }

    static func load<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { decode($0) }
    }

    static func save<T: Encodable>(_ value: T, _ key: String) {
        UserDefaults.standard.set(encode(value), forKey: key)
    }
}

/// One JSON file with everything the learner did. Version 1 files (videos + A1) still restore.
struct StudyBackup: Codable {
    let version: Int
    let watched: Set<Int>
    let favorites: Set<Int>
    let notes: [Int: String]
    var a1: A1SavedState? = nil
    var daily: DailySavedState? = nil
}

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum BackupService {
    static func make() -> BackupDocument? {
        let backup = StudyBackup(version: 2,
                                 watched: LessonStore.load(LessonStore.watchedKey) ?? [],
                                 favorites: LessonStore.load(LessonStore.favoritesKey) ?? [],
                                 notes: LessonStore.load(LessonStore.notesKey) ?? [:],
                                 a1: A1SavedState.load(),
                                 daily: DailySavedState.load())
        guard let data = try? JSONEncoder().encode(backup) else { return nil }
        return BackupDocument(data: data)
    }

    /// Merges a backup into the current data. Returns a string key for the result message.
    static func restore(from url: URL) -> String {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let backup = try? JSONDecoder().decode(StudyBackup.self, from: data) else { return "backup.unreadable" }
        guard backup.version == 1 || backup.version == 2 else { return "backup.unsupported" }
        let watched: Set<Int> = LessonStore.load(LessonStore.watchedKey) ?? []
        let favorites: Set<Int> = LessonStore.load(LessonStore.favoritesKey) ?? []
        let notes: [Int: String] = LessonStore.load(LessonStore.notesKey) ?? [:]
        LessonStore.save(watched.union(backup.watched), LessonStore.watchedKey)
        LessonStore.save(favorites.union(backup.favorites), LessonStore.favoritesKey)
        LessonStore.save(notes.merging(backup.notes) { current, _ in current }, LessonStore.notesKey)
        if let a1 = backup.a1 {
            A1SavedState.load().merged(with: a1).save()
            NotificationCenter.default.post(name: A1SavedState.changed, object: nil)
        }
        if let daily = backup.daily {
            DailySavedState.load().merged(with: daily).save()
            NotificationCenter.default.post(name: DailySavedState.changed, object: nil)
        }
        return "backup.restored"
    }
}
