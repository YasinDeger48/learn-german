import SwiftUI

struct Lesson: Codable, Identifiable {
    let id: Int
    let title: String
    let url: URL
    let level: String
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
        WindowGroup { LessonsView(lessons: lessons) }
    }
}

struct LessonsView: View {
    let lessons: [Lesson]
    @AppStorage("watchedLessons") private var storedProgress = Data()
    @State private var selectedLevel: String?

    private let levels = ["A1", "A2", "B1", "B2", "C1"]
    private let accent = Color(red: 0.18, green: 0.48, blue: 0.36)
    private var watched: Set<Int> {
        (try? JSONDecoder().decode(Set<Int>.self, from: storedProgress)) ?? []
    }

    var body: some View {
        let completed = watched
        let next = lessons.first { !completed.contains($0.id) }
        let activeLevel = selectedLevel ?? next?.level ?? levels[0]
        let count = lessons.filter { completed.contains($0.id) }.count
        NavigationStack {
            List {
                if lessons.isEmpty {
                    Text("Ders listesi yüklenemedi.")
                } else {
                    Section("İlerleme") {
                        ProgressView(value: Double(count), total: Double(lessons.count)) {
                            Text("\(count) / \(lessons.count) ders tamamlandı")
                        }
                    }
                    Section("Sıradaki ders") {
                        if let next {
                            Text(next.title).font(.headline)
                            Link("YouTube’da izle", destination: next.url)
                            Button("İzlendi olarak işaretle") {
                                setWatched(next.id, true)
                            }
                        } else {
                            Text("Tüm dersleri tamamladın!")
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
                        ForEach(lessons.filter { $0.level == activeLevel }) { lesson in
                            HStack {
                                Link(lesson.title, destination: lesson.url)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                let isWatched = completed.contains(lesson.id)
                                Button {
                                    setWatched(lesson.id, !isWatched)
                                } label: {
                                    Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
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
            .navigationTitle("Almanca Derslerim")
            .tint(accent)
        }
    }

    private func setWatched(_ id: Int, _ isWatched: Bool) {
        var updated = watched
        if isWatched { updated.insert(id) }
        else { updated.remove(id) }
        if let encoded = try? JSONEncoder().encode(updated) {
            storedProgress = encoded
        }
    }
}

