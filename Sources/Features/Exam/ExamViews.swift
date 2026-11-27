import SwiftUI

// MARK: - Certificates

/// A Deschly certificate: earned by passing a mock exam (60 of 100 points or more). Stored on the phone.
struct Certificate: Codable, Identifiable, Hashable {
    let id: String
    let level: String
    let date: Date
    /// ExamModule raw value → points out of 25.
    let scores: [String: Int]
    /// ExamModule raw value → [right answers, questions] (Sprechen: [content points covered, content points]).
    /// Missing in certificates saved before this was added.
    var counts: [String: [Int]]? = nil

    var total: Int { scores.values.reduce(0, +) }
    func score(_ module: ExamModule) -> Int? { scores[module.rawValue] }
}

/// One finished mock exam.
struct ExamAttempt: Codable, Hashable {
    let level: String
    let date: Date
    let scores: [String: Int]
    var counts: [String: [Int]]? = nil
    var total: Int { scores.values.reduce(0, +) }
    var passed: Bool { total >= ExamStore.passMark && weakModules.isEmpty }
    /// B1/B2 (like Goethe B1/B2): every module needs 60 % (15 of 25) too; these are the ones below it.
    var weakModules: [ExamModule] {
        guard ExamStore.modular(level) else { return [] }
        return ExamModule.allCases.filter { (scores[$0.rawValue] ?? 0) < ExamStore.moduleMark }
    }
}

/// "12/15" for a module's right answers, or nil when they were not saved.
func examCount(_ counts: [String: [Int]]?, _ module: ExamModule) -> String? {
    guard let pair = counts?[module.rawValue], pair.count == 2 else { return nil }
    return "\(pair[0])/\(pair[1])"
}

enum ExamStore {
    static let passMark = 60
    /// Minimum points per module (of 25) where the levels ask for it.
    static let moduleMark = 15
    static func modular(_ level: String) -> Bool { ["B1", "B2"].contains(level.uppercased()) }
    static let changed = Notification.Name("ExamStoreChanged")
    private static let certificatesKey = "certificates"
    private static let attemptsKey = "examAttempts"
    static let nameKey = "certificateName"
    private static let candidateKey = "examCandidate"

    /// "DS-0427": the learner's candidate number on the exam ticket and the result sheet, made once.
    static var candidateNumber: String {
        var number = UserDefaults.standard.integer(forKey: candidateKey)
        if number == 0 {
            number = Int.random(in: 1000...9999)
            UserDefaults.standard.set(number, forKey: candidateKey)
        }
        return "DS-\(number)"
    }

    static func certificates() -> [Certificate] { load(certificatesKey) ?? [] }
    static func attempts() -> [ExamAttempt] { load(attemptsKey) ?? [] }

    static func certificate(_ id: String) -> Certificate? { certificates().first { $0.id == id } }

    /// Saves the attempt; a pass gives the level's certificate (or a better one replaces it).
    @discardableResult
    static func record(_ attempt: ExamAttempt) -> Certificate? {
        var list = attempts()
        list.append(attempt)
        save(Array(list.suffix(50)), attemptsKey)
        defer { NotificationCenter.default.post(name: changed, object: nil) }
        guard attempt.passed else { return nil }
        var certificates = certificates()
        if let old = certificates.first(where: { $0.level == attempt.level }), old.total >= attempt.total { return old }
        let certificate = Certificate(id: newID(attempt.level), level: attempt.level, date: attempt.date, scores: attempt.scores,
                                      counts: attempt.counts)
        certificates.removeAll { $0.level == attempt.level }
        certificates.append(certificate)
        certificates.sort { $0.level < $1.level }
        save(certificates, certificatesKey)
        return certificate
    }

    /// From a backup: keeps the better certificate of each level.
    static func merge(_ other: [Certificate]) {
        var mine = certificates()
        for certificate in other {
            if let old = mine.first(where: { $0.level == certificate.level }), old.total >= certificate.total { continue }
            mine.removeAll { $0.level == certificate.level }
            mine.append(certificate)
        }
        mine.sort { $0.level < $1.level }
        save(mine, certificatesKey)
        NotificationCenter.default.post(name: changed, object: nil)
    }

    private static func newID(_ level: String) -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let code = String((0..<4).map { _ in letters.randomElement()! })
        return "DSC-\(level)-\(code)"
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }
}

// MARK: - Exam tab

/// The exam as an exam hall (design: https://claude.ai/artifact/NQ2HHKrJvwcEqNS54SG74g): an admission ticket,
/// how ready each module is, the last attempt and the way in.
struct ExamHomeView: View {
    @EnvironmentObject private var levels: LevelModels
    @EnvironmentObject private var daily: DailyModel
    @State private var attempts = ExamStore.attempts()
    @State private var certificates = ExamStore.certificates()

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        let level = levels.active
        let last = attempts.last { $0.level == level }
        let certificate = certificates.first { $0.level == level }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LevelChips()
                ExamTicket(level: level)

                if levels.hasPractice(level) {
                    Text(t("exam.readyTitle")).font(.footnote.weight(.bold)).foregroundColor(DS.muted)
                    let model = levels.model(level)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(ExamModule.allCases) { module in
                            readiness(module, module.progress(model, daily: daily))
                        }
                    }
                }

                if let last { lastCard(last, certificate) }

                Text(t("exam.rules", ExamStore.passMark)
                     + (ExamStore.modular(level) ? " " + t("exam.rulesModule", ExamStore.moduleMark) : ""))
                    .font(.footnote).foregroundColor(DS.muted)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink(value: AppRoute.examRun) {
                    Text(t("exam.enter", ExamModule.totalMinutes))
                        .font(DS.text(16, .semibold))
                        .foregroundColor(DS.onGold)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(!levels.hasPractice(level))
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("tab.exam"))
        .onReceive(NotificationCenter.default.publisher(for: ExamStore.changed)) { _ in
            attempts = ExamStore.attempts()
            certificates = ExamStore.certificates()
        }
    }

    private func readiness(_ module: ExamModule, _ progress: Double) -> some View {
        let percent = Int((progress * 100).rounded())
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(module.title).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink)
                Spacer(minLength: 4)
                Text(t("exam.minutes", module.minutes)).font(.caption.monospacedDigit()).foregroundColor(DS.muted)
            }
            ProgressView(value: min(1, max(0, progress))).tint(module.color)
            Text(t(percent < 60 ? "exam.readyStudy" : "exam.readyPct", percent))
                .font(.caption).foregroundColor(percent < 60 ? DS.error : DS.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func lastCard(_ attempt: ExamAttempt, _ certificate: Certificate?) -> some View {
        let content = HStack(spacing: 12) {
            GoalRing(progress: Double(attempt.total) / 100, size: 52, lineWidth: 6,
                     color: attempt.passed ? DS.success : DS.error) {
                Text("\(attempt.total)").font(.system(size: 15, weight: .heavy).monospacedDigit()).foregroundColor(DS.ink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(t("exam.last", attempt.date.formatted(.dateTime.day().month(.abbreviated))))
                    .font(.caption).foregroundColor(DS.muted)
                Text(t("exam.total", attempt.total) + " · " + (attempt.passed ? t("exam.passed") : t("exam.notPassed")))
                    .font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if certificate != nil {
                Image(systemName: "rosette").font(.system(size: 18, weight: .bold)).foregroundColor(DS.goldDeep)
            }
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        if let certificate {
            NavigationLink(value: AppRoute.certificate(certificate.id)) { content }.buttonStyle(.pressable)
        } else {
            content
        }
    }
}

/// The admission ticket on the exam page: level, candidate number, total time and the pass mark.
struct ExamTicket: View {
    let level: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("exam.format").uppercased())
                    .font(.caption.weight(.bold)).kerning(0.6)
                    .foregroundColor(DS.onNightMuted)
                (Text(level).foregroundColor(DS.onNight) + Text(".").foregroundColor(DS.gold))
                    .font(.system(size: 48, weight: .heavy))
                Text(t("exam.title", level)).font(.subheadline).foregroundColor(DS.onNightMuted)
            }
            .padding(16)
            DashLine()
                .stroke(DS.onNightMuted.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .frame(height: 1)
                .padding(.horizontal, 14)
            HStack(alignment: .top, spacing: 10) {
                field(t("exam.candidate"), ExamStore.candidateNumber)
                field(t("exam.time"), t("exam.minutes", ExamModule.totalMinutes))
                field(t("exam.passLine"), "\(ExamStore.passMark)/100")
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.night, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundColor(DS.onNightMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundColor(DS.onNight)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Points per module in four boxes: "18/25", the right answers ("12/15 ✓") and the module.
struct ScoreGrid: View {
    let scores: [String: Int]
    var counts: [String: [Int]]? = nil
    var light = true

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ExamModule.allCases) { module in
                VStack(spacing: 2) {
                    (Text(scores[module.rawValue].map { "\($0)" } ?? "–").font(.system(size: 17, weight: .heavy)).foregroundColor(DS.ink)
                        + Text("/25").font(.system(size: 12, weight: .semibold)).foregroundColor(DS.muted))
                        .monospacedDigit()
                    if let count = examCount(counts, module) {
                        Text("\(count) ✓").font(.caption2.monospacedDigit().weight(.semibold)).foregroundColor(DS.success)
                    }
                    Text(module.title).font(.caption2).foregroundColor(DS.muted)
                }
                .accessibilityElement(children: .combine)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(DS.ground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: - Taking the exam

/// The exam: the rules first, then the four modules one after the other (each timed and scored out of 25),
/// a short break between them, and at the end the result sheet.
struct ExamRunView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var daily: DailyModel
    @AppStorage(ExamStore.nameKey) private var name = ""
    @State private var begun = false
    @State private var scores: [String: Int] = [:]
    @State private var counts: [String: [Int]] = [:]
    @State private var speakingTask: SpeakingTask?
    /// Schreiben: a form (A1) or a message, then a message, like Goethe Teil 1 and 2. Empty: questions instead.
    @State private var writingTasks: [WritingTask] = []
    /// The module on screen. Kept apart from "the next module", which changes as soon as a module is scored.
    @State private var running: ExamModule?
    @State private var result: (attempt: ExamAttempt, certificate: Certificate?)?
    @Environment(\.dismiss) private var dismiss

    private var next: ExamModule? { ExamModule.allCases.first { scores[$0.rawValue] == nil } }
    private var lastDone: ExamModule? { ExamModule.allCases.last { scores[$0.rawValue] != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let result {
                    resultSheet(result.attempt, result.certificate)
                } else if !begun {
                    rules
                } else if let next {
                    if let lastDone { breakCard(lastDone) }
                    nextCard(next)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 8)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("exam.title", model.level))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: Binding(get: { running != nil }, set: { if !$0 { running = nil } })) {
            if let running { destination(running) }
        }
        .onAppear {
            if speakingTask == nil { speakingTask = SpeakingBank.tasks(model.level).randomElement() }
            if writingTasks.isEmpty { writingTasks = Self.pickWriting(model.level) }
        }
        .onChange(of: scores) { _ in finishIfDone() }
    }

    static func pickWriting(_ level: String) -> [WritingTask] {
        let all = WritingBank.tasks(level).shuffled()
        let messages = all.filter { $0.kind != "form" }
        if let form = all.first(where: { $0.kind == "form" }), let message = messages.first { return [form, message] }
        return Array(messages.prefix(2))
    }

    // MARK: Rules

    private var rules: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("exam.rulesTitle")).font(DS.display(28)).foregroundColor(DS.ink)
            VStack(spacing: 8) {
                rule("headphones", t("exam.rule.headphones"))
                rule("timer", t("exam.rule.timer"))
                rule("arrow.uturn.forward", t("exam.rule.skip"))
                rule("nosign", t("exam.rule.noHelp"))
            }
            Text(t("exam.order")).font(.footnote.weight(.bold)).foregroundColor(DS.muted).padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(Array(ExamModule.allCases.enumerated()), id: \.element) { index, module in
                    if index > 0 { Divider().padding(.leading, 28) }
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(module.color).frame(width: 10, height: 10)
                        Text(module.title).font(.system(size: 15, weight: .semibold)).foregroundColor(DS.ink)
                        Spacer()
                        Text(t("exam.minutes", module.minutes)).font(.subheadline.monospacedDigit()).foregroundColor(DS.muted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                }
            }
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button {
                withAnimation { begun = true }
                running = ExamModule.allCases.first
            } label: {
                Text(t("exam.readyGo"))
                    .font(DS.text(16, .semibold))
                    .foregroundColor(DS.onGold)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(DS.gold, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DS.ink)
                .frame(width: 36, height: 36)
                .background(DS.chip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(text).font(.subheadline).foregroundColor(DS.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Between modules

    private func breakCard(_ module: ExamModule) -> some View {
        let points = scores[module.rawValue] ?? 0
        return VStack(spacing: 10) {
            GoalRing(progress: Double(points) / 25, size: 116, lineWidth: 10, color: module.color) {
                Text("\(points)").font(.system(size: 32, weight: .heavy).monospacedDigit()).foregroundColor(DS.ink)
            }
            Text(t("exam.moduleDone", module.title)).font(.footnote.weight(.bold)).foregroundColor(DS.muted)
            if let count = examCount(counts, module) {
                Text(t(module == .sprechen ? "exam.countSpeak" : "exam.countRight", count))
                    .font(.caption.monospacedDigit()).foregroundColor(DS.muted)
            }
            Text(t("exam.breakTitle")).font(DS.display(24)).foregroundColor(DS.ink)
            Text(t("exam.breakSub")).font(.subheadline).foregroundColor(DS.muted)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func nextCard(_ module: ExamModule) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(module.color).frame(width: 8, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("exam.next").uppercased()).font(.caption.weight(.bold)).foregroundColor(DS.muted)
                    Text(module.title + " · " + t("exam.minutes", module.minutes))
                        .font(.system(size: 17, weight: .bold)).foregroundColor(DS.ink)
                    Text(t("exam.part.\(module.rawValue)")).font(.caption).foregroundColor(DS.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack(spacing: 6) {
                ForEach(ExamModule.allCases) { item in
                    Capsule()
                        .fill(scores[item.rawValue] != nil ? item.color : (item == module ? item.color.opacity(0.35) : DS.chip))
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
            Button { running = module } label: {
                Text(t("exam.startModule", module.title))
                    .font(DS.text(16, .semibold))
                    .foregroundColor(DS.onGold)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(DS.gold, in: Capsule())
            }
            .buttonStyle(.pressable)
        }
    }

    @ViewBuilder
    private func destination(_ module: ExamModule) -> some View {
        switch module {
        case .sprechen:
            if let task = speakingTask {
                SpeakTaskView(task: task) { covered, total, percent in
                    counts[module.rawValue] = [covered, total]
                    scores[module.rawValue] = points(percent, 100)
                }
            }
        case .schreiben where !writingTasks.isEmpty:
            ExamWritingView(tasks: writingTasks, seconds: module.minutes * 60) { percent in
                counts[module.rawValue] = nil
                scores[module.rawValue] = points(percent, 100)
            }
        default:
            A1QuizView(title: module.title, exam: true, free: true, partPoints: 25, timeLimit: module.minutes * 60,
                       onFinish: { correct, total in
                counts[module.rawValue] = [correct, total]
                scores[module.rawValue] = points(correct, total)
            }) {
                questions(module)
            }
        }
    }

    private func points(_ correct: Int, _ total: Int) -> Int {
        total == 0 ? 0 : Int((Double(correct) / Double(total) * 25).rounded())
    }

    /// Questions of one module, never-seen first.
    private func questions(_ module: ExamModule) -> [A1Question] {
        func take(_ mode: A1Mode, _ n: Int) -> [A1Question] {
            let pool = model.questions.filter { $0.mode == mode }
            let unseen = pool.filter { !model.state.seen.contains($0.id) }.shuffled()
            return Array((unseen.count >= n ? unseen : pool.shuffled()).prefix(n))
        }
        switch module {
        case .hoeren:
            return take(.hoeren, 12) + take(.listen, 3)
        case .lesen:
            // Questions about three daily texts of the level (and reading games where the level has them).
            let texts = (daily.texts[model.level] ?? []).shuffled().prefix(3)
            let fromTexts = texts.flatMap { ReadingQuiz.questions(for: $0, words: model.content?.words ?? []) }
            return Array((take(.reading, 5) + fromTexts).prefix(15))
        case .schreiben:
            return take(.write, 5) + take(.order, 3) + take(.cloze, 2)
        case .sprechen:
            return []
        }
    }

    private func finishIfDone() {
        guard result == nil, ExamModule.allCases.allSatisfy({ scores[$0.rawValue] != nil }) else { return }
        let attempt = ExamAttempt(level: model.level, date: Date(), scores: scores, counts: counts)
        let certificate = ExamStore.record(attempt)
        StreakStore.shared.record()
        StreakStore.shared.addXP(attempt.passed ? 50 : 20)
        withAnimation { result = (attempt, certificate) }
        UINotificationFeedbackGenerator().notificationOccurred(attempt.passed ? .success : .warning)
    }

    // MARK: Result sheet

    private func resultSheet(_ attempt: ExamAttempt, _ certificate: Certificate?) -> some View {
        let weakest = ExamModule.allCases.min { (attempt.scores[$0.rawValue] ?? 0) < (attempt.scores[$1.rawValue] ?? 0) }
        let weakestPoints = weakest.flatMap { attempt.scores[$0.rawValue] } ?? 25
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                // The result sheet is German on purpose, like the certificate.
                VStack(alignment: .leading, spacing: 3) {
                    Text("ERGEBNIS · PRÜFUNG \(attempt.level)").font(.caption.weight(.bold)).kerning(0.6).foregroundColor(DS.muted)
                    if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(name).font(.system(size: 19, weight: .bold)).foregroundColor(DS.ink)
                    }
                    Text("\(ExamStore.candidateNumber) · \(attempt.date.formatted(.dateTime.day().month(.twoDigits).year()))")
                        .font(.caption.monospacedDigit()).foregroundColor(DS.muted)
                }
                Rectangle().fill(DS.ink).frame(height: 2)
                ForEach(ExamModule.allCases) { module in
                    resultRow(module, attempt)
                }
                HStack {
                    Text("Gesamt").font(.system(size: 16, weight: .heavy))
                    Spacer()
                    Text("\(attempt.total)/100").font(.system(size: 16, weight: .heavy).monospacedDigit())
                }
                .foregroundColor(DS.ink)
                .padding(.top, 2)
                Text(t("exam.passLineNote", ExamStore.passMark)).font(.caption).foregroundColor(DS.muted)
            }
            .padding(16)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Text(attempt.passed ? "BESTANDEN" : "NOCH NICHT")
                    .font(.system(size: 16, weight: .heavy)).kerning(1.4)
                    .foregroundColor(attempt.passed ? DS.success : DS.error)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(attempt.passed ? DS.success : DS.error, lineWidth: 3))
                    .rotationEffect(.degrees(-12))
                    .padding(.top, 20)
                    .padding(.trailing, 14)
                    .accessibilityLabel(attempt.passed ? t("exam.resultPassed") : t("exam.resultFailed"))
            }

            if let weakest, weakestPoints < 20 {
                Text(t("exam.weakTip", weakest.title, weakestPoints))
                    .font(.subheadline).foregroundColor(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(DS.errorSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !attempt.passed {
                if !attempt.weakModules.isEmpty {
                    Text(t("exam.moduleBelow", ExamStore.moduleMark, attempt.weakModules.map(\.title).joined(separator: ", ")))
                        .font(.footnote.weight(.semibold)).foregroundColor(DS.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(t("exam.tryAgain", ExamStore.passMark)).font(.footnote).foregroundColor(DS.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let certificate {
                NavigationLink(value: AppRoute.certificate(certificate.id)) {
                    Label(t("exam.openCert"), systemImage: "rosette")
                        .font(DS.text(16, .semibold))
                        .foregroundColor(DS.onGold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            Button(t("done.finish")) { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .buttonStyle(.bordered)
        }
    }

    private func resultRow(_ module: ExamModule, _ attempt: ExamAttempt) -> some View {
        let points = attempt.scores[module.rawValue] ?? 0
        let weak = attempt.weakModules.contains(module)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(module.title).font(.system(size: 15, weight: .semibold)).foregroundColor(DS.ink)
                if let count = examCount(attempt.counts, module) {
                    Text(t(module == .sprechen ? "exam.countSpeak" : "exam.countRight", count))
                        .font(.caption.monospacedDigit()).foregroundColor(DS.muted)
                }
                Spacer()
                Text("\(points)/25").font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundColor(weak ? DS.error : DS.ink)
            }
            ProgressView(value: Double(points), total: 25).tint(weak ? DS.error : module.color)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Mock exam Schreiben: the tasks one after the other on one timer; at zero what is written is handed in.
/// The form counts once, a message twice (Goethe A1: 5 and 10 points).
struct ExamWritingView: View {
    let tasks: [WritingTask]
    let seconds: Int
    let onFinish: (Int) -> Void
    @State private var step = 0
    @State private var results: [Int] = []
    @State private var startedAt = Date()
    @State private var now = Date()
    @State private var submit = 0
    @State private var timeUp = false
    @State private var total: Int?
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var left: Int { max(0, seconds - Int(now.timeIntervalSince(startedAt))) }

    var body: some View {
        Group {
            if let total {
                VStack(spacing: 14) {
                    GoalRing(progress: Double(total) / 100, size: 110, lineWidth: 10, color: ExamModule.schreiben.color) {
                        Text("\(Int((Double(total) / 4).rounded()))").font(.system(size: 30, weight: .heavy).monospacedDigit())
                    }
                    Text(t("exam.moduleDone", ExamModule.schreiben.title)).font(.footnote.weight(.bold)).foregroundColor(DS.muted)
                    if timeUp {
                        Label(t("exam.timeUp"), systemImage: "timer").font(.footnote.weight(.semibold)).foregroundColor(DS.error)
                            .multilineTextAlignment(.center)
                    }
                    Text(t("exam.backToExam")).font(.subheadline).foregroundColor(DS.muted).multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.ground.ignoresSafeArea())
            } else if step < tasks.count {
                let task = tasks[step]
                Group {
                    if task.kind == "form" {
                        WritingFormView(task: task, onFinish: handIn, submitSignal: submit)
                    } else {
                        WritingMessageView(task: task, onFinish: handIn, submitSignal: submit)
                    }
                }
                .id(step)
                .safeAreaInset(edge: .top) {
                    Text(t("exam.writingPart", step + 1, tasks.count))
                        .font(.caption.weight(.bold)).foregroundColor(DS.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(DS.ground)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if total == nil {
                    Label(String(format: "%02d:%02d", left / 60, left % 60), systemImage: "timer")
                        .labelStyle(.titleAndIcon)
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .foregroundColor(left < 300 ? DS.error : DS.ink)
                        .accessibilityLabel(t("exam.timeLeft", left / 60))
                }
            }
        }
        .onAppear { now = Date() }
        .onReceive(clock) { date in
            guard total == nil else { return }
            now = date
            if left == 0 && !timeUp {
                timeUp = true
                submit += 1
            }
        }
    }

    private func handIn(_ percent: Int) {
        guard results.count == step else { return }
        results.append(percent)
        if step + 1 < tasks.count && !timeUp {
            step += 1
        } else {
            // Time is up: the tasks not reached give nothing.
            while results.count < tasks.count { results.append(0) }
            let weights = tasks.map { $0.kind == "form" ? 1.0 : 2.0 }
            let sum = zip(results, weights).map { Double($0) * $1 }.reduce(0, +)
            let value = Int((sum / weights.reduce(0, +)).rounded())
            withAnimation { total = value }
            onFinish(value)
        }
    }
}

// MARK: - Certificate page and PDF

/// The certificate itself, A4 landscape (842 × 595 pt), used on screen (scaled) and for the PDF.
struct CertificateCard: View {
    let certificate: Certificate
    let name: String

    static let size = CGSize(width: 842, height: 595)

    var body: some View {
        let gold = Color(red: 0.89, green: 0.77, blue: 0.42)
        ZStack {
            Color(red: 1, green: 0.992, blue: 0.965)
            RoundedRectangle(cornerRadius: 18).stroke(gold, lineWidth: 3).padding(22)
            RoundedRectangle(cornerRadius: 12).stroke(gold.opacity(0.5), lineWidth: 1).padding(32)
            VStack(spacing: 10) {
                (Text("deschly").foregroundColor(Color(red: 0.055, green: 0.059, blue: 0.047))
                    + Text(".").foregroundColor(Color(red: 0.949, green: 0.761, blue: 0.188)))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("ZERTIFIKAT · LEVEL CERTIFICATE")
                    .font(.system(size: 13, weight: .bold)).kerning(4)
                    .foregroundColor(Color(red: 0.6, green: 0.44, blue: 0))
                Text("Deutsch \(certificate.level)")
                    .font(.system(size: 64, weight: .regular, design: .serif))
                    .foregroundColor(.black)
                    .padding(.top, 6)
                Text(name.isEmpty ? " " : name)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.25)).frame(height: 1) }
                Text("hat die Deschly-Probeprüfung \(certificate.level) bestanden.")
                    .font(.system(size: 15)).foregroundColor(.black.opacity(0.75))
                HStack(spacing: 34) {
                    ForEach(ExamModule.allCases) { module in
                        VStack(spacing: 2) {
                            Text("\(certificate.score(module) ?? 0)/25").font(.system(size: 22, weight: .bold)).foregroundColor(.black)
                            Text(module.title).font(.system(size: 12)).foregroundColor(.black.opacity(0.6))
                            if let count = examCount(certificate.counts, module) {
                                // The certificate is German on purpose (like its other texts).
                                Text("\(count) " + (module == .sprechen ? "Inhaltspunkte" : "richtig"))
                                    .font(.system(size: 10)).foregroundColor(.black.opacity(0.5))
                            }
                        }
                    }
                    VStack(spacing: 2) {
                        Text("\(certificate.total)/100").font(.system(size: 22, weight: .heavy)).foregroundColor(.black)
                        Text("Gesamt").font(.system(size: 12)).foregroundColor(.black.opacity(0.6))
                    }
                }
                .padding(.top, 14)
                HStack {
                    Text(certificate.date.formatted(.dateTime.day().month(.twoDigits).year()))
                    Spacer()
                    Text("Nr. \(certificate.id)")
                }
                .font(.system(size: 12)).foregroundColor(.black.opacity(0.6))
                .padding(.horizontal, 70)
                .padding(.top, 18)
                Text("Deschly-Lernzertifikat; kein offizielles Prüfungszeugnis einer Prüfungsinstitution.")
                    .font(.system(size: 10)).foregroundColor(.black.opacity(0.5))
            }
            .padding(50)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

struct CertificateDetailView: View {
    let certificate: Certificate
    @AppStorage(ExamStore.nameKey) private var name = ""
    @State private var pdf: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GeometryReader { geo in
                    let scale = geo.size.width / CertificateCard.size.width
                    CertificateCard(certificate: certificate, name: name)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: geo.size.width, height: CertificateCard.size.height * scale, alignment: .topLeading)
                        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                }
                .aspectRatio(CertificateCard.size.width / CertificateCard.size.height, contentMode: .fit)

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("cert.nameLabel")).font(.subheadline.weight(.semibold))
                    TextField(t("cert.namePlaceholder"), text: $name)
                        .textContentType(.name)
                        .padding(12)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let pdf {
                    ShareLink(item: pdf) {
                        Label(t("cert.savePdf"), systemImage: "square.and.arrow.down")
                            .font(DS.text(16, .semibold))
                            .foregroundColor(DS.onGold)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(DS.gold, in: Capsule())
                    }
                }
                Text(t("cert.note")).font(.footnote).foregroundColor(DS.muted)
            }
            .padding(DS.gutter)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("cert.title", certificate.level))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // ImageRenderer works on the main thread: wait for the push animation to finish first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { if pdf == nil { pdf = makePDF() } }
        }
        .onChange(of: name) { typed in
            // Draw again only when typing pauses (ImageRenderer on every key made typing lag).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if name == typed { pdf = makePDF() } }
        }
    }

    /// Draws the card into a one-page PDF in the temporary folder.
    @MainActor
    private func makePDF() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Deschly-\(certificate.level)-Zertifikat.pdf")
        let renderer = ImageRenderer(content: CertificateCard(certificate: certificate, name: name))
        var made = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            made = true
        }
        return made ? url : nil
    }
}

/// Profile → My certificates.
struct CertificatesListView: View {
    @State private var certificates = ExamStore.certificates()

    var body: some View {
        List {
            if certificates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("cert.empty")).font(.headline)
                    Text(t("cert.emptySub", ExamStore.passMark)).font(.subheadline).foregroundColor(DS.muted)
                }
                .padding(.vertical, 8)
            }
            ForEach(certificates) { certificate in
                NavigationLink(value: AppRoute.certificate(certificate.id)) {
                    HStack(spacing: 12) {
                        Image(systemName: "rosette")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DS.onGold)
                            .frame(width: 40, height: 40)
                            .background(DS.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Deutsch \(certificate.level)").font(.headline)
                            Text("\(certificate.date.formatted(date: .abbreviated, time: .omitted)) · \(certificate.total)/100")
                                .font(.subheadline).foregroundColor(DS.muted)
                        }
                    }
                }
            }
        }
        .navigationTitle(t("cert.mine"))
        .onReceive(NotificationCenter.default.publisher(for: ExamStore.changed)) { _ in certificates = ExamStore.certificates() }
    }
}
