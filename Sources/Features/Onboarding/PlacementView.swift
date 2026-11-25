import SwiftUI

/// Short placement test: 4 gap-fill questions per level from the level's own grammar items, A1 first.
/// A level counts as passed with 3 of 4 right; the test stops at the first level that is not passed,
/// and that level is recommended (all passed: B2).
struct PlacementQuestion: Identifiable {
    let id = UUID()
    let level: String
    let prompt: String
    let options: [String]
    let answer: String
}

enum PlacementEngine {
    static let levels = ["A1", "A2", "B1", "B2"]
    static let perLevel = 4
    static let passMark = 3

    /// Four questions from four different topics of one level.
    static func questions(for level: String) -> [PlacementQuestion] {
        guard let content = A1Content.load(level) else { return [] }
        var byTopic: [Int: [A1GrammarItem]] = [:]
        for item in content.grammarItems where item.q.contains("___") && item.options.count >= 3 {
            byTopic[item.topic, default: []].append(item)
        }
        let picked = byTopic.keys.shuffled().prefix(perLevel).compactMap { byTopic[$0]?.randomElement() }
        return picked.map { item in
            PlacementQuestion(level: level, prompt: item.q, options: Array(item.options.prefix(4)).shuffled(), answer: item.options[0])
        }
    }
}

struct PlacementTestView: View {
    /// Strings in the language being chosen (onboarding) or the app language (settings).
    let text: (String) -> String
    let onDone: (String) -> Void

    @State private var levelIndex = 0
    @State private var questions: [PlacementQuestion] = []
    @State private var loaded = false
    @State private var index = 0
    @State private var correctInLevel = 0
    @State private var picked: String?

    private var totalMax: Int { PlacementEngine.levels.count * PlacementEngine.perLevel }
    private var answeredSoFar: Int { levelIndex * PlacementEngine.perLevel + index }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(value: Double(answeredSoFar), total: Double(totalMax)).tint(DS.accent)
            HStack {
                Text(PlacementEngine.levels[levelIndex]).font(.subheadline.weight(.bold)).foregroundColor(DS.accent)
                Spacer()
                Text(text("placement.hint")).font(.footnote).foregroundColor(DS.muted)
            }
            if index < questions.count {
                let q = questions[index]
                Text(q.prompt.replacingOccurrences(of: "___", with: "_____"))
                    .font(DS.display(24, heavy: false))
                    .foregroundColor(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
                VStack(spacing: 10) {
                    ForEach(q.options, id: \.self) { option in
                        Button {
                            choose(option, q)
                        } label: {
                            Text(option)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(color(for: option, q) == nil ? DS.ink : .white)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(color(for: option, q) ?? DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.hairline, lineWidth: color(for: option, q) == nil ? 1 : 0))
                        }
                        .buttonStyle(.pressable)
                        .disabled(picked != nil)
                    }
                    Button(text("placement.dontKnow")) { choose("", q) }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(picked != nil)
                }
            }
            Spacer()
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            questions = PlacementEngine.questions(for: "A1")
            // Content missing (should not happen): start at A1.
            if questions.isEmpty { onDone("A1") }
        }
    }

    private func color(for option: String, _ q: PlacementQuestion) -> Color? {
        guard let picked else { return nil }
        if option == q.answer { return DS.success }
        if option == picked { return DS.error }
        return nil
    }

    private func choose(_ option: String, _ q: PlacementQuestion) {
        picked = option
        if option == q.answer { correctInLevel += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { next() }
    }

    private func next() {
        picked = nil
        if index + 1 < questions.count {
            index += 1
            return
        }
        let level = PlacementEngine.levels[levelIndex]
        let passed = correctInLevel >= PlacementEngine.passMark
        if !passed || levelIndex + 1 >= PlacementEngine.levels.count {
            onDone(level)
            return
        }
        levelIndex += 1
        correctInLevel = 0
        index = 0
        questions = PlacementEngine.questions(for: PlacementEngine.levels[levelIndex])
        if questions.isEmpty { onDone(PlacementEngine.levels[levelIndex - 1]) }
    }
}

/// Four level cards; the recommended one is marked.
struct LevelPickerList: View {
    let text: (String) -> String
    var recommended: String?
    @Binding var selection: String

    var body: some View {
        VStack(spacing: 10) {
            ForEach(PlacementEngine.levels, id: \.self) { level in
                let on = level == selection
                Button {
                    selection = level
                } label: {
                    HStack(spacing: 14) {
                        Text(level)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(on ? DS.onGold : DS.accent)
                            .frame(width: 48, height: 48)
                            .background(on ? DS.gold : DS.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(text("level.\(level.lowercased()).name")).font(.system(size: 16, weight: .bold))
                                    .foregroundColor(on ? DS.onNight : DS.ink)
                                if level == recommended {
                                    Text(text("placement.recommended"))
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(DS.onGold)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(DS.gold, in: Capsule())
                                }
                            }
                            Text(text("placement.desc.\(level.lowercased())"))
                                .font(.footnote)
                                .foregroundColor(on ? DS.onNightMuted : DS.muted)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(on ? DS.night : DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// The placement test from Settings (app language), as a sheet.
struct PlacementSheet: View {
    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var levels: LevelModels
    @Environment(\.dismiss) private var dismiss
    @State private var result: String?
    @State private var selection = "A1"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let result {
                    Text(t("placement.resultTitle", result)).font(DS.display(28))
                    Text(t("placement.resultBody")).foregroundColor(DS.muted)
                    LevelPickerList(text: { t($0) }, recommended: result, selection: $selection)
                    Spacer()
                    Button(t("placement.startWith", selection)) {
                        daily.level = selection
                        levels.active = selection
                        dismiss()
                    }
                    .buttonStyle(PillButtonStyle())
                } else {
                    PlacementTestView(text: { t($0) }) { level in
                        selection = level
                        result = level
                    }
                }
            }
            .padding(DS.gutter)
            .background(DS.ground.ignoresSafeArea())
            .navigationTitle(t("placement.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(t("common.close")) { dismiss() } }
            }
        }
    }
}
