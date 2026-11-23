import SwiftUI

/// YouTube video lessons with watched marks, favourites and notes (stored on the device).
struct LessonsView: View {
    let lessons: [Lesson]
    @AppStorage(LessonStore.watchedKey) private var storedProgress = Data()
    @AppStorage(LessonStore.favoritesKey) private var storedFavorites = Data()
    @AppStorage(LessonStore.notesKey) private var storedNotes = Data()
    @AppStorage("selectedLessonLevel") private var selectedLevel = ""
    @State private var pendingChange: (lesson: Lesson, isWatched: Bool)?
    @State private var search = ""
    @State private var onlyUnwatched = false
    @State private var onlyFavorites = false

    private let levels = ["A1", "A2", "B1", "B2", "C1"]
    private var watched: Set<Int> { LessonStore.decode(storedProgress) ?? [] }
    private var favorites: Set<Int> { LessonStore.decode(storedFavorites) ?? [] }
    private var notes: [Int: String] { LessonStore.decode(storedNotes) ?? [:] }

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
        List {
            if lessons.isEmpty {
                Text(t("videos.loadFailed"))
            } else {
                Section(t("videos.progress")) {
                    ProgressView(value: Double(count), total: Double(lessons.count)) {
                        progressLabel(t("videos.all"), completed: count, total: lessons.count)
                    }
                    if !levelLessons.isEmpty {
                        ProgressView(value: Double(levelCount), total: Double(levelLessons.count)) {
                            progressLabel(t("videos.level", activeLevel), completed: levelCount, total: levelLessons.count)
                        }
                    }
                }
                Section(t("videos.next")) {
                    if let next {
                        nextLessonCard(next)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } else if levelLessons.isEmpty {
                        Text(t("videos.noneInLevel", activeLevel))
                    } else {
                        Text(t("videos.levelDone", activeLevel))
                    }
                }
                Section(t("videos.lessons")) {
                    Picker(t("videos.levelPicker"), selection: Binding(get: { activeLevel }, set: { selectedLevel = $0 })) {
                        ForEach(levels, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: $onlyUnwatched) { Label(t("videos.onlyUnwatched"), systemImage: "circle") }
                    Toggle(isOn: $onlyFavorites) { Label(t("videos.onlyFavorites"), systemImage: "star") }
                    if visibleLessons.isEmpty {
                        Text(t("videos.noMatch")).foregroundStyle(.secondary)
                    }
                    ForEach(visibleLessons) { lesson in
                        lessonRow(lesson, completed: completed, favorites: savedFavorites, notes: savedNotes)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("tab.videos"))
        .searchable(text: $search, prompt: t("videos.search"))
        .navigationDestination(for: Int.self) { id in
            if let lesson = lessons.first(where: { $0.id == id }) {
                Form {
                    Section(t("videos.video")) {
                        Link(t("videos.watch"), destination: lesson.url)
                    }
                    Section {
                        TextEditor(text: Binding(get: { notes[id] ?? "" }, set: { saveNote($0, for: id) }))
                            .frame(minHeight: 160)
                            .accessibilityLabel(t("videos.note"))
                    } header: {
                        Text(t("videos.note"))
                    } footer: {
                        Text(t("videos.noteHint"))
                    }
                }
                .navigationTitle(lesson.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .tint(DS.ink)
        .alert(
            pendingChange?.isWatched == true ? t("videos.markWatched") : t("videos.unmarkWatched"),
            isPresented: Binding(get: { pendingChange != nil }, set: { if !$0 { pendingChange = nil } }),
            presenting: pendingChange
        ) { change in
            Button(t("common.cancel"), role: .cancel) {}
            Button(change.isWatched ? t("videos.mark") : t("videos.unmark")) {
                setWatched(change.lesson.id, change.isWatched)
            }
        } message: { change in
            Text(change.lesson.title)
        }
    }

    private func lessonRow(_ lesson: Lesson, completed: Set<Int>, favorites: Set<Int>, notes: [Int: String]) -> some View {
        HStack {
            NavigationLink(value: lesson.id) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                    if let note = notes[lesson.id], !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            let isFavorite = favorites.contains(lesson.id)
            Button { toggleFavorite(lesson.id) } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? DS.goldDeep : Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? t("videos.unfavorite") : t("videos.favorite"))
            let isWatched = completed.contains(lesson.id)
            Button { pendingChange = (lesson, !isWatched) } label: {
                Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isWatched ? DS.success : Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(lesson.title))
            .accessibilityValue(isWatched ? t("videos.watched") : t("videos.notWatched"))
        }
    }

    private func progressLabel(_ title: String, completed: Int, total: Int) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            Text("\(completed)/\(total)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func nextLessonCard(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lesson.title).font(DS.display(22, heavy: false)).foregroundColor(DS.onNight)
            Link(destination: lesson.url) {
                Label(t("videos.watch"), systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle())
            Button { pendingChange = (lesson, true) } label: {
                Label(t("videos.markWatchedShort"), systemImage: "checkmark.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle(foreground: DS.onNight, border: DS.onNightMuted))
        }
        .padding(18)
        .background(DS.night, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func setWatched(_ id: Int, _ isWatched: Bool) {
        var updated = watched
        if isWatched { updated.insert(id) } else { updated.remove(id) }
        storedProgress = LessonStore.encode(updated)
    }

    private func toggleFavorite(_ id: Int) {
        var updated = favorites
        if updated.remove(id) == nil { updated.insert(id) }
        storedFavorites = LessonStore.encode(updated)
    }

    private func saveNote(_ text: String, for id: Int) {
        var updated = notes
        updated[id] = text.isEmpty ? nil : text
        storedNotes = LessonStore.encode(updated)
    }
}
