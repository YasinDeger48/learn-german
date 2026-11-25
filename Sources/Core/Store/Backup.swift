import SwiftUI
import UniformTypeIdentifiers

/// One JSON file with everything the learner did. Older files (version 1–2, with video marks) still restore;
/// their video fields are ignored.
struct StudyBackup: Codable {
    let version: Int
    var a1: A1SavedState? = nil
    var a2: A1SavedState? = nil
    var b1: A1SavedState? = nil
    var b2: A1SavedState? = nil
    var daily: DailySavedState? = nil
    var streak: StreakState? = nil
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
        let backup = StudyBackup(version: 3,
                                 a1: A1SavedState.load("A1"),
                                 a2: A1SavedState.load("A2"),
                                 b1: A1SavedState.load("B1"),
                                 b2: A1SavedState.load("B2"),
                                 daily: DailySavedState.load(),
                                 streak: StreakStore.shared.state)
        guard let data = try? JSONEncoder().encode(backup) else { return nil }
        return BackupDocument(data: data)
    }

    /// Merges a backup into the current data. Returns a string key for the result message.
    static func restore(from url: URL) -> String {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let backup = try? JSONDecoder().decode(StudyBackup.self, from: data) else { return "backup.unreadable" }
        guard (1...3).contains(backup.version) else { return "backup.unsupported" }
        for (level, saved) in [("A2", backup.a2), ("B1", backup.b1), ("B2", backup.b2)] {
            if let saved { A1SavedState.load(level).merged(with: saved).save(level) }
        }
        if let a1 = backup.a1 {
            A1SavedState.load("A1").merged(with: a1).save("A1")
            NotificationCenter.default.post(name: A1SavedState.changed, object: nil)
        }
        if let streak = backup.streak {
            StreakStore.shared.merge(streak)
        }
        if let daily = backup.daily {
            DailySavedState.load().merged(with: daily).save()
            NotificationCenter.default.post(name: DailySavedState.changed, object: nil)
        }
        return "backup.restored"
    }
}
