import SwiftUI

// MARK: - Content (Resources/content/writing.json, made by tools/writing.py)

struct WritingField: Decodable, Hashable {
    let label: String
    let answers: [String]
}

struct WritingTask: Decodable, Identifiable, Hashable {
    let id: String
    let level: String
    /// "form" (Teil 1) or "message" (Teil 2).
    let kind: String
    let title: LocText
    let text: String?
    let fields: [WritingField]?
    let prompt: String?
    let help: LocText?
    let points: [SpeakingPoint]?
    let minWords: Int?
    let sample: String?
}

private struct WritingFile: Decodable {
    let greeting: [String]
    let closing: [String]
    let tasks: [WritingTask]
}

enum WritingBank {
    private static let file = Bundled.decode(WritingFile.self, "writing")

    static func tasks(_ level: String) -> [WritingTask] { file?.tasks.filter { $0.level == level } ?? [] }
    static func task(_ id: String) -> WritingTask? { file?.tasks.first { $0.id == id } }
    static var greeting: [String] { file?.greeting ?? [] }
    static var closing: [String] { file?.closing ?? [] }

    /// Best result in percent.
    static func best(_ id: String) -> Int? { UserDefaults.standard.object(forKey: "write.best.\(id)") as? Int }

    static func save(_ id: String, percent: Int) {
        if percent > (best(id) ?? -1) { UserDefaults.standard.set(percent, forKey: "write.best.\(id)") }
    }

    /// A form answer is right when it matches one of the accepted answers (case, accents, spaces and dots ignored).
    static func matches(_ input: String, _ answers: [String]) -> Bool {
        func norm(_ s: String) -> String {
            s.lowercased().replacingOccurrences(of: "ß", with: "ss")
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
                .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@")).inverted)
                .filter { !$0.isEmpty }.joined(separator: " ")
        }
        let given = norm(input)
        return !given.isEmpty && answers.contains { norm($0) == given }
    }
}

// MARK: - List

struct WritingHomeView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        let tasks = WritingBank.tasks(model.level)
        List {
            if tasks.isEmpty {
                Text(t("write.soon")).foregroundColor(DS.muted)
            }
            section(t("write.forms"), t("write.formsSub"), tasks.filter { $0.kind == "form" })
            section(t("write.messages"), t("write.messagesSub"), tasks.filter { $0.kind == "message" })
        }
        .navigationTitle("Schreiben")
    }

    @ViewBuilder
    private func section(_ title: String, _ footer: String, _ tasks: [WritingTask]) -> some View {
        if !tasks.isEmpty {
            Section {
                ForEach(tasks) { task in
                    NavigationLink(value: AppRoute.writingTask(task.id)) {
                        HStack {
                            Text(task.title.text)
                            Spacer()
                            if let best = WritingBank.best(task.id) {
                                Text("\(best)%").font(.subheadline.monospacedDigit().weight(.semibold))
                                    .foregroundColor(best >= 60 ? DS.success : DS.muted)
                            }
                        }
                    }
                }
            } header: {
                Text(title)
            } footer: {
                Text(footer)
            }
        }
    }
}

// MARK: - Teil 1: form

struct WritingFormView: View {
    let task: WritingTask
    @State private var inputs: [String] = []
    @State private var checked = false

    private var fields: [WritingField] { task.fields ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("write.formIntro")).font(.subheadline).foregroundColor(DS.muted)
                HStack(alignment: .top, spacing: 10) {
                    Text(task.text ?? "").font(DS.text(17)).foregroundColor(DS.ink)
                    Spacer(minLength: 0)
                    A1SpeakButton(text: task.text ?? "")
                }
                .padding(16)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(spacing: 0) {
                    ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
                        if index > 0 { Divider() }
                        fieldRow(index, field)
                    }
                }
                .padding(.horizontal, 14)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if checked {
                    let right = fields.indices.filter { WritingBank.matches(inputs[$0], fields[$0].answers) }.count
                    Text(t("write.formResult", right, fields.count))
                        .font(DS.text(17, .bold))
                        .foregroundColor(right == fields.count ? DS.success : DS.ink)
                }

                Button(checked ? t("write.again") : t("write.check")) {
                    if checked {
                        inputs = Array(repeating: "", count: fields.count)
                        checked = false
                    } else {
                        check()
                    }
                }
                .buttonStyle(SpeakPrimaryButton())
            }
            .padding(DS.gutter)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(task.title.text)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if inputs.count != fields.count { inputs = Array(repeating: "", count: fields.count) } }
    }

    private func fieldRow(_ index: Int, _ field: WritingField) -> some View {
        let ok = checked && index < inputs.count && WritingBank.matches(inputs[index], field.answers)
        return VStack(alignment: .leading, spacing: 4) {
            Text(field.label).font(.caption.weight(.semibold)).foregroundColor(DS.muted)
            HStack {
                TextField(field.label, text: Binding(get: { index < inputs.count ? inputs[index] : "" },
                                                     set: { if index < inputs.count { inputs[index] = $0 } }))
                    .font(DS.text(17))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(checked)
                if checked {
                    Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(ok ? DS.success : DS.error)
                }
            }
            if checked && !ok {
                Text(t("write.rightAnswer", field.answers.first ?? "")).font(.caption).foregroundColor(DS.success)
            }
        }
        .padding(.vertical, 10)
    }

    private func check() {
        let right = fields.indices.filter { WritingBank.matches(inputs[$0], fields[$0].answers) }.count
        let percent = fields.isEmpty ? 0 : right * 100 / fields.count
        let before = WritingBank.best(task.id) ?? 0
        WritingBank.save(task.id, percent: percent)
        StreakStore.shared.record()
        StreakStore.shared.addXP(max(0, right - before * fields.count / 100) * XP.correct)
        UINotificationFeedbackGenerator().notificationOccurred(right == fields.count ? .success : .warning)
        withAnimation { checked = true }
    }
}

// MARK: - Teil 2: short message

struct WritingMessageView: View {
    let task: WritingTask
    @State private var text = ""
    @State private var checked = false
    @FocusState private var focused: Bool

    private var points: [SpeakingPoint] { task.points ?? [] }
    private var words: Int { SpeechScore.split(text).count }

    /// The three points plus greeting and closing.
    private var checks: [(label: String, ok: Bool)] {
        points.map { ($0.label.text, SpeechScore.mentions(text, $0.keys)) } + [
            (t("write.greeting"), SpeechScore.mentions(text, WritingBank.greeting)),
            (t("write.closing"), SpeechScore.mentions(text, WritingBank.closing)),
            (t("write.length", task.minWords ?? 25), words >= (task.minWords ?? 25)),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.prompt ?? "").font(DS.text(18, .semibold)).foregroundColor(DS.ink)
                    Text(task.help?.text ?? "").font(.subheadline).foregroundColor(DS.muted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(checks.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 10) {
                            Image(systemName: item.ok ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.ok ? DS.success : DS.hairline)
                            Text(item.label).font(DS.text(15)).foregroundColor(DS.ink)
                        }
                    }
                    if !checked {
                        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                            Text("• " + point.say).font(.caption).italic().foregroundColor(DS.muted)
                        }
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .focused($focused)
                        .font(DS.text(17))
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .disabled(checked)
                    if text.isEmpty {
                        Text(t("write.placeholder")).font(DS.text(17)).foregroundColor(DS.muted.opacity(0.7))
                            .padding(.horizontal, 15).padding(.vertical, 18).allowsHitTesting(false)
                    }
                }
                Text(t("write.words", words)).font(.caption.monospacedDigit()).foregroundColor(DS.muted)

                if checked, let sample = task.sample {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(t("speak.sample")).font(.caption.weight(.bold)).foregroundColor(DS.muted).textCase(.uppercase)
                            Spacer()
                            Button { A1Speaker.shared.read(sample, speed: 0.9) } label: {
                                Label(t("speak.listenSample"), systemImage: "speaker.wave.2.fill").font(DS.text(13, .semibold))
                            }
                        }
                        Text(sample).font(DS.text(15)).foregroundColor(DS.ink)
                    }
                    .padding(14)
                    .background(DS.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(checked ? t("write.again") : t("write.check")) {
                    if checked {
                        checked = false
                    } else {
                        check()
                    }
                }
                .buttonStyle(SpeakPrimaryButton())
                .disabled(!checked && words < 3)
            }
            .padding(DS.gutter)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(task.title.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(t("common.done")) { focused = false }
            }
        }
    }

    private func check() {
        focused = false
        let ok = checks.filter { $0.ok }.count
        let percent = checks.isEmpty ? 0 : ok * 100 / checks.count
        let before = WritingBank.best(task.id) ?? 0
        WritingBank.save(task.id, percent: percent)
        StreakStore.shared.record()
        if percent > before { StreakStore.shared.addXP((percent - before) / 10 * 2) }
        UINotificationFeedbackGenerator().notificationOccurred(percent == 100 ? .success : .warning)
        withAnimation { checked = true }
    }
}
