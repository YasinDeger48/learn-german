import SwiftUI
import UIKit

// MARK: - Quiz

struct A1QuizView: View {
    @EnvironmentObject private var model: A1Model
    let title: String
    var exam = false
    var review = false
    var resetMode: A1Mode? = nil
    var onFinish: ((Int, Int) -> Void)? = nil
    let makeSession: () -> [A1Question]

    init(title: String, exam: Bool = false, review: Bool = false, resetMode: A1Mode? = nil,
         onFinish: ((Int, Int) -> Void)? = nil, makeSession: @escaping () -> [A1Question]) {
        self.title = title
        self.exam = exam
        self.review = review
        self.resetMode = resetMode
        self.onFinish = onFinish
        self.makeSession = makeSession
    }

    @State private var session: [A1Question] = []
    @State private var started = false
    @State private var index = 0
    @State private var picked: String?
    @State private var typed = ""
    @State private var order: [Int] = []
    @State private var revealed = false
    @State private var wasCorrect = false
    @State private var score = 0
    @State private var missed: [A1Question] = []
    @State private var showText = false
    @State private var examSaved = false
    @FocusState private var typingFocused: Bool

    var body: some View {
        Group {
            if !started {
                ProgressView()
            } else if session.isEmpty {
                emptyState
            } else if index >= session.count {
                summary
            } else {
                question(session[index])
            }
        }
        .background(DS.ground.ignoresSafeArea())
        .tint(DS.accent)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { A1Speaker.shared.stop() }
        .onAppear {
            if !started {
                session = makeSession()
                started = true
                playIfNeeded()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            LinaAvatar(size: 96)
            Text(review ? t("quiz.noMistakes") : t("quiz.allSeen"))
                .font(DS.display(24, heavy: false))
                .multilineTextAlignment(.center)
            if let mode = resetMode {
                Text(t("quiz.resetHint"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button(t("quiz.reset")) {
                    model.reset(mode)
                    restart()
                }
                .buttonStyle(PillButtonStyle())
            }
        }
        .padding(24)
    }

    private var summary: some View {
        let total = session.count
        let points = total == 0 ? 0 : Int((Double(score) / Double(total) * 100).rounded())
        return List {
            Section {
                VStack(spacing: 8) {
                    if exam {
                        Text(t("quiz.points", points)).font(DS.display(40))
                        Text(points >= 60 ? t("quiz.passed") : t("quiz.notPassed"))
                            .font(DS.text(15, .medium))
                            .foregroundStyle(points >= 60 ? DS.success : DS.error)
                    } else {
                        Text(t("quiz.score", score, total)).font(DS.display(40))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                Button {
                    restart()
                } label: {
                    Text(onFinish == nil ? t("quiz.continueNew") : t("quiz.again"))
                }
                .buttonStyle(PillButtonStyle())
                .listRowBackground(Color.clear)
            }
            if !missed.isEmpty {
                Section(t("quiz.missedSection")) {
                    ForEach(missed) { q in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(q.prompt).font(.subheadline)
                            Text("✓ \(q.answer)").font(.subheadline.bold()).foregroundStyle(DS.success)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .onAppear {
            if !examSaved {
                examSaved = true
                if exam { model.saveExam(points) }
                onFinish?(score, total)
            }
        }
    }

    private func restart() {
        session = makeSession()
        index = 0
        score = 0
        missed = []
        examSaved = false
        resetAnswer()
        playIfNeeded()
    }

    private func resetAnswer() {
        picked = nil
        typed = ""
        order = []
        revealed = false
        wasCorrect = false
        showText = false
    }

    private func playIfNeeded() {
        guard index < session.count else { return }
        let q = session[index]
        guard q.dialog != nil || q.speakFirst != nil else { return }
        let times = q.mode == .listen || q.mode == .hoeren ? 2 : 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { play(q, times: times) }
    }

    private func play(_ q: A1Question, slow: Bool = false, times: Int = 1) {
        if let dialog = q.dialog {
            A1Speaker.shared.play(dialog, slow: slow, times: times)
        } else if let text = q.speakFirst {
            A1Speaker.shared.say(text, slow: slow, times: times)
        }
    }

    private func question(_ q: A1Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProgressView(value: Double(index), total: Double(session.count))
                HStack {
                    Text(t("quiz.progress", index + 1, session.count)).font(DS.text(12).monospacedDigit())
                    Spacer()
                    Text(q.label).font(.caption).lineLimit(1)
                }
                .foregroundStyle(.secondary)
                promptCard(q)
                switch q.kind {
                case .choice: choiceButtons(q)
                case .order: orderArea(q)
                case .typing: typingArea(q)
                }
                if revealed { feedback(q) }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func promptCard(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.mode.title).font(DS.text(12, .semibold)).foregroundStyle(DS.muted)
            if let context = q.context {
                DisclosureGroup(isExpanded: $showText) {
                    Text(context).font(.callout).padding(.top, 4)
                } label: {
                    Label(t("quiz.readText"), systemImage: "doc.text")
                }
                .onAppear { showText = true }
            }
            if q.dialog != nil || q.speakFirst != nil {
                HStack {
                    Button {
                        play(q)
                    } label: {
                        Label(t("common.listen"), systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        play(q, slow: true)
                    } label: {
                        Label(t("common.slow"), systemImage: "tortoise.fill")
                    }
                    .buttonStyle(.bordered)
                }
                if q.mode == .listen || q.mode == .hoeren {
                    Text(t("quiz.playsTwice"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(q.prompt)
                .font(q.prompt.count < 40 ? DS.display(28, heavy: false) : DS.display(21, heavy: false))
                .fixedSize(horizontal: false, vertical: true)
            if let detail = q.detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .deschlyCard(padding: 18)
    }

    private func choiceButtons(_ q: A1Question) -> some View {
        VStack(spacing: 10) {
            ForEach(q.options, id: \.self) { option in
                Button {
                    guard !revealed else { return }
                    picked = option
                    check(q, correct: option == q.answer)
                } label: {
                    HStack {
                        Text(option)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(q.mode == .artikel ? a1ArticleColor(option) : Color.primary)
                            .font(q.mode == .artikel ? Font.title3.bold() : Font.body)
                        Spacer()
                        if revealed && option == q.answer {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.success)
                        } else if revealed && option == picked {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(DS.error)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(optionBackground(q, option), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(optionBorder(q, option), lineWidth: revealed && (option == q.answer || option == picked) ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func optionBackground(_ q: A1Question, _ option: String) -> Color {
        if revealed && option == q.answer { return DS.successSoft }
        if revealed && option == picked { return DS.errorSoft }
        return DS.surface
    }

    private func optionBorder(_ q: A1Question, _ option: String) -> Color {
        if revealed && option == q.answer { return DS.success }
        if revealed && option == picked { return DS.error }
        return DS.hairline
    }

    private func orderArea(_ q: A1Question) -> some View {
        let chosen = order.map { q.options[$0] }.joined(separator: " ")
        return VStack(alignment: .leading, spacing: 12) {
            Text(chosen.isEmpty ? t("quiz.tapWords") : chosen)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .padding(12)
                .deschlyCard(padding: 2)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(Array(q.options.enumerated()), id: \.offset) { item in
                    let used = order.contains(item.offset)
                    Button {
                        guard !revealed else { return }
                        if let position = order.firstIndex(of: item.offset) {
                            order.remove(at: position)
                        } else {
                            order.append(item.offset)
                        }
                    } label: {
                        Text(item.element)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(used ? DS.chip : DS.surface, in: Capsule())
                            .overlay(Capsule().stroke(DS.hairline, lineWidth: used ? 0 : 1))
                            .foregroundStyle(used ? Color.secondary : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !revealed {
                HStack {
                    Button(t("quiz.clear")) { order = [] }
                        .buttonStyle(.bordered)
                        .disabled(order.isEmpty)
                    Button {
                        check(q, correct: chosen == q.answer)
                    } label: {
                        Text(t("quiz.check")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(order.count != q.options.count)
                }
            }
        }
    }

    private func typingArea(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(t("quiz.typeGerman"), text: $typed, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title3)
                .padding(12)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DS.hairline, lineWidth: 1))
                .focused($typingFocused)
                .disabled(revealed)
            HStack(spacing: 6) {
                ForEach(["ä", "ö", "ü", "ß", "Ä", "Ö", "Ü"], id: \.self) { letter in
                    Button(letter) { typed += letter }
                        .buttonStyle(.bordered)
                        .disabled(revealed)
                }
            }
            if !revealed {
                Button {
                    typingFocused = false
                    let answer = a1Normalize(typed)
                    let ok = ([q.answer] + q.accepted).contains { a1Normalize($0) == answer }
                    picked = typed
                    check(q, correct: ok)
                } label: {
                    Text(t("quiz.check")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func check(_ q: A1Question, correct: Bool) {
        revealed = true
        wasCorrect = correct
        if correct {
            score += 1
        } else {
            missed.append(q)
        }
        model.record(q, correct: correct)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(correct ? .success : .error)
    }

    private func feedback(_ q: A1Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                LinaAvatar(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wasCorrect ? linaPraise : "Kein Problem!")
                        .font(DS.display(21, heavy: false))
                        .foregroundStyle(wasCorrect ? DS.success : DS.error)
                    Text(wasCorrect ? t("quiz.correct") : t("quiz.answerIs", q.answer))
                        .font(DS.text(14, .medium))
                        .foregroundStyle(DS.ink)
                }
            }
            if let explanation = q.explanation {
                Text(explanation).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                if q.dialog != nil || q.speakAfter != nil || q.speakFirst != nil {
                    Button {
                        if let speak = q.speakAfter {
                            A1Speaker.shared.say(speak)
                        } else {
                            play(q)
                        }
                    } label: {
                        Label(t("common.listen"), systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    A1Speaker.shared.stop()
                    index += 1
                    resetAnswer()
                    playIfNeeded()
                } label: {
                    Text(index + 1 < session.count ? t("quiz.next") : t("quiz.result")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(wasCorrect ? DS.successSoft : DS.errorSoft, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
    }

    /// Lina's short German praise, varied so it does not feel robotic.
    private var linaPraise: String {
        let lines = ["Super gemacht!", "Richtig!", "Sehr gut!", "Genau!", "Toll!"]
        return lines[(index + score) % lines.count]
    }
}
