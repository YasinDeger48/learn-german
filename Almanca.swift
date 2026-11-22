import SwiftUI
import UniformTypeIdentifiers

struct Lesson: Codable, Identifiable {
    let id: Int
    let title: String
    let url: URL
    let level: String
}

private struct StudyBackup: Codable {
    let version: Int
    let watched: Set<Int>
    let favorites: Set<Int>
    let notes: [Int: String]
    var a1: A1SavedState? = nil
}

private struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@main
struct AlmancaApp: App {
    private let lessons: [Lesson] = {
        guard let url = Bundle.main.url(forResource: "lessons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Lesson].self, from: data) else {
            return []
        }
        return list
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                A1HomeView()
                    .tabItem { Label("A1 Hazırlık", systemImage: "graduationcap.fill") }
                LessonsView(lessons: lessons)
                    .tabItem { Label("Video dersler", systemImage: "play.rectangle.fill") }
            }
        }
    }
}

struct LessonsView: View {
    let lessons: [Lesson]
    @AppStorage("watchedLessons") private var storedProgress = Data()
    @AppStorage("favoriteLessons") private var storedFavorites = Data()
    @AppStorage("lessonNotes") private var storedNotes = Data()
    @AppStorage("selectedLessonLevel") private var selectedLevel = ""
    @State private var pendingChange: (lesson: Lesson, isWatched: Bool)?
    @State private var search = ""
    @State private var onlyUnwatched = false
    @State private var onlyFavorites = false
    @State private var exportingBackup = false
    @State private var importingBackup = false
    @State private var backupDocument: BackupDocument?
    @State private var backupStatus: String?

    private let levels = ["A1", "A2", "B1", "B2", "C1"]
    private let accent = Color(red: 0.18, green: 0.48, blue: 0.36)
    private var watched: Set<Int> {
        (try? JSONDecoder().decode(Set<Int>.self, from: storedProgress)) ?? []
    }
    private var favorites: Set<Int> {
        (try? JSONDecoder().decode(Set<Int>.self, from: storedFavorites)) ?? []
    }
    private var notes: [Int: String] {
        (try? JSONDecoder().decode([Int: String].self, from: storedNotes)) ?? [:]
    }

    var body: some View {
        let completed = watched
        let savedFavorites = favorites
        let savedNotes = notes
        let firstUnwatched = lessons.first { !completed.contains($0.id) }
        let activeLevel = levels.contains(selectedLevel) ? selectedLevel : (firstUnwatched?.level ?? levels[0])
        let levelLessons = lessons.filter { $0.level == activeLevel }
        let next = levelLessons.first { !completed.contains($0.id) }
        let levelCount = levelLessons.filter { completed.contains($0.id) }.count
        let count = lessons.filter { completed.contains($0.id) }.count
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleLessons = (query.isEmpty ? levelLessons : lessons).filter { lesson in
            (!onlyUnwatched || !completed.contains(lesson.id)) &&
            (!onlyFavorites || savedFavorites.contains(lesson.id)) &&
            (query.isEmpty || lesson.title.localizedStandardContains(query) ||
                (savedNotes[lesson.id] ?? "").localizedStandardContains(query))
        }
        NavigationStack {
            List {
                if lessons.isEmpty {
                    Text("Ders listesi yüklenemedi.")
                } else {
                    Section("İlerleme") {
                        ProgressView(value: Double(count), total: Double(lessons.count)) {
                            progressLabel("Tüm dersler", completed: count, total: lessons.count)
                        }
                        if !levelLessons.isEmpty {
                            ProgressView(value: Double(levelCount), total: Double(levelLessons.count)) {
                                progressLabel("\(activeLevel) seviyesi", completed: levelCount, total: levelLessons.count)
                            }
                        }
                        if let backupStatus {
                            Text(backupStatus).font(.footnote)
                        }
                    }
                    Section("Sıradaki ders") {
                        if let next {
                            nextLessonCard(next)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                        } else {
                            if levelLessons.isEmpty {
                                Text("\(activeLevel) seviyesinde ders yok.")
                            } else {
                                Text("\(activeLevel) seviyesindeki tüm dersleri tamamladın!")
                            }
                        }
                    }
                    Section("Dersler") {
                        Picker("Seviye", selection: Binding(
                            get: { activeLevel },
                            set: { selectedLevel = $0 }
                        )) {
                            ForEach(levels, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Toggle(isOn: $onlyUnwatched) {
                            Label("Yalnızca izlenmeyenler", systemImage: "circle")
                        }
                        Toggle(isOn: $onlyFavorites) {
                            Label("Yalnızca favoriler", systemImage: "star")
                        }
                        if visibleLessons.isEmpty {
                            Text("Eşleşen ders yok.").foregroundStyle(.secondary)
                        }
                        ForEach(visibleLessons) { lesson in
                            HStack {
                                NavigationLink(value: lesson.id) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lesson.title)
                                        if let note = savedNotes[lesson.id], !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }
                                let isFavorite = savedFavorites.contains(lesson.id)
                                Button {
                                    toggleFavorite(lesson.id)
                                } label: {
                                    Image(systemName: isFavorite ? "star.fill" : "star")
                                        .foregroundStyle(isFavorite ? Color.orange : Color.secondary)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(isFavorite ? "Favorilerden kaldır" : "Favorilere ekle")
                                let isWatched = completed.contains(lesson.id)
                                Button {
                                    pendingChange = (lesson, !isWatched)
                                } label: {
                                    Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(isWatched ? accent : Color.secondary)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(Text(lesson.title))
                                .accessibilityValue(isWatched ? "İzlendi" : "İzlenmedi")
                                .accessibilityHint("İzlenme durumunu değiştirir")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Almancam")
            .searchable(text: $search, prompt: "Tüm derslerde ve notlarda ara")
            .navigationDestination(for: Int.self) { id in
                if let lesson = lessons.first(where: { $0.id == id }) {
                    Form {
                        Section("Video") {
                            Link("YouTube’da izle", destination: lesson.url)
                        }
                        Section {
                            TextEditor(text: Binding(
                                get: { notes[id] ?? "" },
                                set: { saveNote($0, for: id) }
                            ))
                            .frame(minHeight: 160)
                            .accessibilityLabel("Ders notu")
                        } header: {
                            Text("Ders notu")
                        } footer: {
                            Text("Yeni kelimeleri ve örnek cümleleri buraya yazabilirsin.")
                        }
                    }
                    .navigationTitle(lesson.title)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Yedek dosyası kaydet", action: prepareBackup)
                        Button("Yedekten geri yükle") { importingBackup = true }
                    } label: {
                        Label("Yedekleme", systemImage: "ellipsis.circle")
                    }
                }
            }
            .tint(accent)
            .fileExporter(
                isPresented: $exportingBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "Almancam-Yedek"
            ) { result in
                switch result {
                case .success: backupStatus = "Yedek dosyası kaydedildi."
                case .failure: backupStatus = "Yedek dosyası kaydedilemedi."
                }
            }
            .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
                restoreBackup(result)
            }
            .alert(
                pendingChange?.isWatched == true
                    ? "Ders izlendi olarak işaretlensin mi?"
                    : "İzlendi işareti kaldırılsın mı?",
                isPresented: Binding(
                    get: { pendingChange != nil },
                    set: { if !$0 { pendingChange = nil } }
                ),
                presenting: pendingChange
            ) { change in
                Button("İptal", role: .cancel) {}
                Button(change.isWatched ? "İşaretle" : "Kaldır") {
                    setWatched(change.lesson.id, change.isWatched)
                }
            } message: { change in
                Text(change.lesson.title)
            }
        }
    }

    private func progressLabel(_ title: String, completed: Int, total: Int) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            Text("\(completed)/\(total)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(completed) / \(total) ders tamamlandı")
        }
    }

    private func nextLessonCard(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .font(.title2)
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text(lesson.title).font(.title3.bold())
            Link(destination: lesson.url) {
                Label("YouTube’da izle", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                pendingChange = (lesson, true)
            } label: {
                Label("İzlendi olarak işaretle", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private func setWatched(_ id: Int, _ isWatched: Bool) {
        var updated = watched
        if isWatched { updated.insert(id) }
        else { updated.remove(id) }
        if let encoded = try? JSONEncoder().encode(updated) {
            storedProgress = encoded
        }
    }

    private func toggleFavorite(_ id: Int) {
        var updated = favorites
        if updated.remove(id) == nil { updated.insert(id) }
        if let encoded = try? JSONEncoder().encode(updated) {
            storedFavorites = encoded
        }
    }

    private func saveNote(_ text: String, for id: Int) {
        var updated = notes
        updated[id] = text.isEmpty ? nil : text
        if let encoded = try? JSONEncoder().encode(updated) {
            storedNotes = encoded
        }
    }

    private func prepareBackup() {
        let backup = StudyBackup(version: 1, watched: watched, favorites: favorites, notes: notes, a1: A1SavedState.load())
        guard let data = try? JSONEncoder().encode(backup) else {
            backupStatus = "Yedek dosyası oluşturulamadı."
            return
        }
        backupDocument = BackupDocument(data: data)
        exportingBackup = true
    }

    private func restoreBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            let backup = try JSONDecoder().decode(StudyBackup.self, from: Data(contentsOf: url))
            guard backup.version == 1 else {
                backupStatus = "Bu yedek sürümü desteklenmiyor."
                return
            }
            let encoder = JSONEncoder()
            let restoredProgress = try encoder.encode(watched.union(backup.watched))
            let restoredFavorites = try encoder.encode(favorites.union(backup.favorites))
            let restoredNotes = try encoder.encode(notes.merging(backup.notes) { current, _ in current })
            storedProgress = restoredProgress
            storedFavorites = restoredFavorites
            storedNotes = restoredNotes
            if let a1 = backup.a1 {
                A1SavedState.load().merged(with: a1).save()
                NotificationCenter.default.post(name: A1SavedState.changed, object: nil)
            }
            backupStatus = "Yedek içe aktarıldı. Mevcut notlar korundu."
        } catch {
            backupStatus = "Yedek okunamadı. Bir Almancam yedek dosyası seç."
        }
    }
}

