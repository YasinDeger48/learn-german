import SwiftUI

// MARK: - Certificates

/// A Deschly certificate: earned by passing a mock exam (60 of 100 points or more). Stored on the phone.
struct Certificate: Codable, Identifiable, Hashable {
    let id: String
    let level: String
    let date: Date
    /// ExamModule raw value → points out of 25.
    let scores: [String: Int]

    var total: Int { scores.values.reduce(0, +) }
    func score(_ module: ExamModule) -> Int? { scores[module.rawValue] }
}

/// One finished mock exam.
struct ExamAttempt: Codable, Hashable {
    let level: String
    let date: Date
    let scores: [String: Int]
    var total: Int { scores.values.reduce(0, +) }
    var passed: Bool { total >= ExamStore.passMark }
}

enum ExamStore {
    static let passMark = 60
    static let changed = Notification.Name("ExamStoreChanged")
    private static let certificatesKey = "certificates"
    private static let attemptsKey = "examAttempts"
    static let nameKey = "certificateName"

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
        let certificate = Certificate(id: newID(attempt.level), level: attempt.level, date: attempt.date, scores: attempt.scores)
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

struct ExamHomeView: View {
    @EnvironmentObject private var levels: LevelModels
    @EnvironmentObject private var daily: DailyModel
    @State private var attempts = ExamStore.attempts()
    @State private var certificates = ExamStore.certificates()

    var body: some View {
        let level = levels.active
        let last = attempts.last { $0.level == level }
        let certificate = certificates.first { $0.level == level }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LevelChips()
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("exam.format")).font(.subheadline).foregroundColor(DS.muted)
                    Text(t("exam.title", level)).font(DS.display(30)).foregroundColor(DS.ink)
                }
                VStack(spacing: 0) {
                    ForEach(Array(ExamModule.allCases.enumerated()), id: \.element) { index, module in
                        if index > 0 { Divider().padding(.leading, 56) }
                        HStack(spacing: 12) {
                            Image(systemName: module.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(module.color)
                                .frame(width: 32, height: 32)
                                .background(module.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(module.title).font(.system(size: 15, weight: .semibold))
                                Text(t("exam.part.\(module.rawValue)")).font(.caption).foregroundColor(DS.muted)
                            }
                            Spacer()
                            Text(t("exam.minutes", module.minutes)).font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let last { lastCard(last) }

                if let certificate {
                    NavigationLink(value: AppRoute.certificate(certificate.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: "rosette")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(DS.onGold)
                                .frame(width: 40, height: 40)
                                .background(DS.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t("exam.certReady", level)).font(.system(size: 15, weight: .bold)).foregroundColor(DS.onNight)
                                Text(t("exam.certReadySub")).font(.caption).foregroundColor(DS.onNightMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(DS.onNightMuted)
                        }
                        .padding(14)
                        .background(DS.night, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                }

                Text(t("exam.rules", ExamStore.passMark)).font(.footnote).foregroundColor(DS.muted)

                NavigationLink(value: AppRoute.examRun) {
                    Text(t("exam.start", ExamModule.allCases.map(\.minutes).reduce(0, +)))
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

    private func lastCard(_ attempt: ExamAttempt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("exam.last", attempt.date.formatted(.dateTime.day().month(.abbreviated))).uppercased())
                    .font(.caption.weight(.bold)).foregroundColor(DS.muted)
                Spacer()
                Text(attempt.passed ? t("exam.passed") : t("exam.notPassed"))
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(attempt.passed ? DS.success : DS.error, in: Capsule())
            }
            ScoreGrid(scores: attempt.scores)
            Text(t("exam.total", attempt.total)).font(.footnote).foregroundColor(DS.ink)
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Points per module in four boxes.
struct ScoreGrid: View {
    let scores: [String: Int]
    var light = true

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ExamModule.allCases) { module in
                VStack(spacing: 2) {
                    Text(scores[module.rawValue].map { "\($0)" } ?? "–").font(.system(size: 17, weight: .heavy)).foregroundColor(DS.ink)
                    Text(module.title).font(.caption2).foregroundColor(DS.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(DS.ground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: - Taking the exam

/// The four modules one after the other. Each module's round is scored out of 25.
struct ExamRunView: View {
    @EnvironmentObject private var model: A1Model
    @EnvironmentObject private var daily: DailyModel
    @State private var scores: [String: Int] = [:]
    @State private var speakingTask: SpeakingTask?
    @State private var result: (attempt: ExamAttempt, certificate: Certificate?)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("exam.runNote")).font(.subheadline).foregroundColor(DS.muted)
                VStack(spacing: 0) {
                    ForEach(Array(ExamModule.allCases.enumerated()), id: \.element) { index, module in
                        if index > 0 { Divider().padding(.leading, 56) }
                        row(module, enabled: index == 0 || scores[ExamModule.allCases[index - 1].rawValue] != nil)
                    }
                }
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let result {
                    resultCard(result.attempt, result.certificate)
                    Button(t("done.finish")) { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 8)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("exam.title", model.level))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if speakingTask == nil { speakingTask = SpeakingBank.tasks(model.level).randomElement() }
        }
        .onChange(of: scores) { _ in finishIfDone() }
    }

    @ViewBuilder
    private func row(_ module: ExamModule, enabled: Bool) -> some View {
        let done = scores[module.rawValue]
        let label = HStack(spacing: 12) {
            Image(systemName: done != nil ? "checkmark" : module.icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(done != nil ? .white : module.color)
                .frame(width: 32, height: 32)
                .background(done != nil ? DS.success : module.color.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(module.title).font(.system(size: 15, weight: .semibold)).foregroundColor(DS.ink)
                Text(t("exam.minutes", module.minutes) + " · " + t("exam.part.\(module.rawValue)")).font(.caption).foregroundColor(DS.muted)
            }
            Spacer()
            if let done {
                Text("\(done)/25").font(.subheadline.monospacedDigit().weight(.bold)).foregroundColor(DS.ink)
            } else {
                Image(systemName: enabled ? "chevron.right" : "lock.fill").font(.caption.weight(.bold)).foregroundColor(DS.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())

        if done != nil || !enabled {
            label.opacity(enabled ? 1 : 0.5)
        } else {
            NavigationLink { destination(module) } label: { label }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func destination(_ module: ExamModule) -> some View {
        switch module {
        case .sprechen:
            if let task = speakingTask {
                SpeakTaskView(task: task) { covered, total in
                    scores[module.rawValue] = points(covered, total)
                }
            }
        default:
            A1QuizView(title: module.title, exam: true, free: true, onFinish: { correct, total in
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
        let attempt = ExamAttempt(level: model.level, date: Date(), scores: scores)
        let certificate = ExamStore.record(attempt)
        StreakStore.shared.record()
        StreakStore.shared.addXP(attempt.passed ? 50 : 20)
        withAnimation { result = (attempt, certificate) }
        UINotificationFeedbackGenerator().notificationOccurred(attempt.passed ? .success : .warning)
    }

    private func resultCard(_ attempt: ExamAttempt, _ certificate: Certificate?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(attempt.passed ? t("exam.resultPassed") : t("exam.resultFailed")).font(DS.display(26)).foregroundColor(DS.ink)
            ScoreGrid(scores: attempt.scores)
            Text(t("exam.total", attempt.total)).font(.subheadline.weight(.semibold))
            if let certificate {
                NavigationLink(value: AppRoute.certificate(certificate.id)) {
                    Label(t("exam.openCert"), systemImage: "rosette")
                        .font(DS.text(16, .semibold))
                        .foregroundColor(DS.onGold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
            } else if !attempt.passed {
                Text(t("exam.tryAgain", ExamStore.passMark)).font(.footnote).foregroundColor(DS.muted)
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .onChange(of: name) { _ in pdf = makePDF() }
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
