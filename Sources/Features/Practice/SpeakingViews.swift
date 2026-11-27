import SwiftUI
import UIKit

// MARK: - Content (Resources/content/speaking.json, made by tools/speaking.py)

struct SpeakingPoint: Decodable, Hashable {
    let label: LocText
    let say: String
    let keys: [String]
}

struct SpeakingTask: Decodable, Identifiable, Hashable {
    let id: String
    let level: String
    let seconds: Int
    let title: LocText
    let prompt: String
    let help: LocText
    let points: [SpeakingPoint]
    let sample: String
}

private struct SpeakingFile: Decodable {
    let tasks: [SpeakingTask]
}

enum SpeakingBank {
    private static let all: [SpeakingTask] = Bundled.decode(SpeakingFile.self, "speaking")?.tasks ?? []

    static func tasks(_ level: String) -> [SpeakingTask] { all.filter { $0.level == level } }
    static func task(_ id: String) -> SpeakingTask? { all.first { $0.id == id } }

    /// Best number of points covered in a task.
    static func best(_ id: String) -> Int? {
        UserDefaults.standard.object(forKey: "speak.best.\(id)") as? Int
    }

    static func save(_ id: String, covered: Int) {
        if covered > (best(id) ?? -1) { UserDefaults.standard.set(covered, forKey: "speak.best.\(id)") }
    }

    /// Short example sentences of the level for "repeat after me".
    static func sentences(_ content: A1Content?, count: Int = 8) -> [A1Example] {
        let all = (content?.words ?? []).flatMap(\.ex).filter {
            let n = $0.de.split(separator: " ").count
            return n >= 3 && n <= 12
        }
        return Array(all.shuffled().prefix(count))
    }
}

// MARK: - Home

/// Speaking (Sprechen): repeat after me, and exam-style speaking tasks.
struct SpeakingHomeView: View {
    @EnvironmentObject private var model: A1Model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                NavigationLink(value: A1Route.speakRepeat) {
                    HStack(spacing: 14) {
                        Image(systemName: "repeat")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DS.onGold)
                            .frame(width: 46, height: 46)
                            .background(DS.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("speak.repeatTitle")).font(.system(size: 17, weight: .bold)).foregroundColor(DS.ink)
                            Text(t("speak.repeatSub", 8)).font(.footnote).foregroundColor(DS.muted)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundColor(DS.muted)
                    }
                    .padding(14)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.pressable)

                let tasks = SpeakingBank.tasks(model.level)
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("speak.tasksTitle")).font(.system(size: 20, weight: .heavy)).foregroundColor(DS.ink)
                        Text(t("speak.tasksSub")).font(.footnote).foregroundColor(DS.muted)
                    }
                    .padding(.top, 8)
                    VStack(spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            if index > 0 { Divider().padding(.leading, 58) }
                            taskRow(task, number: index + 1)
                        }
                    }
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("speak.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(model.level) · Sprechen").font(.subheadline.weight(.semibold)).foregroundColor(.white.opacity(0.85))
                Text(t("speak.headline")).font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(t("speak.intro")).font(.footnote).foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "mic.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(DS.onGold)
                .frame(width: 60, height: 60)
                .background(DS.gold, in: Circle())
        }
        .padding(18)
        .background(SpeakStyle.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 4)
    }

    private func taskRow(_ task: SpeakingTask, number: Int) -> some View {
        let best = SpeakingBank.best(task.id)
        let complete = best.map { $0 >= task.points.count } ?? false
        return NavigationLink(value: A1Route.speakTask(task.id)) {
            HStack(spacing: 12) {
                Text("\(number)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(complete ? .white : SpeakStyle.coral)
                    .frame(width: 32, height: 32)
                    .background(complete ? DS.success : SpeakStyle.coral.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title.text).font(.system(size: 15, weight: .bold)).foregroundColor(DS.ink).lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(task.prompt).font(.caption).foregroundColor(DS.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                if let best {
                    Text("\(best)/\(task.points.count)").font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundColor(complete ? DS.success : DS.muted)
                }
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(DS.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum SpeakStyle {
    static let coral = Color(red: 0.91, green: 0.36, blue: 0.29)
    static let gradient = LinearGradient(colors: [Color(red: 0.62, green: 0.16, blue: 0.20), Color(red: 0.86, green: 0.30, blue: 0.27),
                                                  Color(red: 0.95, green: 0.50, blue: 0.30)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Permission

/// Shown until the microphone and speech recognition are allowed.
struct SpeakAccessView: View {
    @ObservedObject var listener: SpeechListener

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: listener.access == .unavailable ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 84, height: 84)
                .background(SpeakStyle.gradient, in: Circle())
            switch listener.access {
            case .unavailable:
                Text(t("speak.unavailable")).multilineTextAlignment(.center).foregroundColor(DS.ink)
            case .denied:
                Text(t("speak.denied")).multilineTextAlignment(.center).foregroundColor(DS.ink)
                Button(t("speak.openSettings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(SpeakPrimaryButton())
            default:
                Text(t("speak.intro")).multilineTextAlignment(.center).foregroundColor(DS.ink)
                Button(t("speak.allow")) { listener.requestAccess() }
                    .buttonStyle(SpeakPrimaryButton())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct SpeakPrimaryButton: ButtonStyle {
    var color: Color = DS.gold
    var foreground: Color = DS.onGold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.text(16, .semibold))
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(color, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// The big round microphone button with a ring that follows the voice.
struct MicButton: View {
    @ObservedObject var listener: SpeechListener
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(SpeakStyle.coral.opacity(0.18))
                    .frame(width: 112, height: 112)
                    .scaleEffect(listener.listening ? 1 + listener.loudness * 0.35 : 0.9)
                    .animation(.easeOut(duration: 0.12), value: listener.loudness)
                Circle()
                    .fill(listener.listening ? SpeakStyle.coral : DS.night)
                    .frame(width: 84, height: 84)
                    .shadow(color: SpeakStyle.coral.opacity(listener.listening ? 0.45 : 0), radius: 14, y: 4)
                Image(systemName: listener.listening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(listener.listening ? .white : DS.gold)
            }
            .frame(width: 130, height: 130)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(listener.listening ? t("speak.stop") : t("speak.tapToSpeak"))
    }
}

// MARK: - Repeat after me

struct SpeakRepeatView: View {
    @EnvironmentObject private var model: A1Model
    /// Sentences per round (today's lesson uses 3).
    var count = 8
    /// Called when the round is finished (today's lesson).
    var onFinish: (() -> Void)? = nil
    @StateObject private var listener = SpeechListener()
    @State private var items: [A1Example] = []
    @State private var index = 0
    @State private var result: SpeechScore.Result?
    @State private var best: [Int: Int] = [:]
    @State private var xp = 0
    @State private var finished = false
    @State private var startFailed = false
    /// Off: the recogniser gets no hint, so the check is honest. On: it expects this sentence and accepts more easily.
    @AppStorage("speak.useHints") private var useHints = false
    @Environment(\.dismiss) private var dismiss

    private var item: A1Example? { index < items.count ? items[index] : nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if listener.access != .granted {
                    SpeakAccessView(listener: listener).padding(.top, 20)
                } else if finished {
                    summary
                } else if let item {
                    practice(item)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 30)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("speak.repeatTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            listener.refreshAccess()
            if items.isEmpty { items = SpeakingBank.sentences(model.content, count: count) }
        }
        .onDisappear {
            listener.cancel()
            A1Speaker.shared.stop()
        }
    }

    private func practice(_ item: A1Example) -> some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                ProgressView(value: Double(index), total: Double(max(1, items.count))).tint(SpeakStyle.coral)
                Text(t("speak.sentenceOf", index + 1, items.count)).font(.caption.monospacedDigit()).foregroundColor(DS.muted)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                if let result {
                    result.words.reduce(Text("")) { text, word in
                        text + Text(word.text + " ").foregroundColor(word.unclear ? DS.goldDeep : (word.ok ? DS.success : DS.error))
                    }
                    .font(DS.text(24, .semibold))
                    if result.words.contains(where: \.unclear) {
                        Text(t("speak.unclear")).font(DS.text(13)).foregroundColor(DS.goldDeep)
                    }
                } else {
                    Text(item.de).font(DS.text(24, .semibold)).foregroundColor(DS.ink)
                }
                if a1ShowsPron() {
                    Text("[\(item.pron)]").font(DS.text(14)).foregroundColor(DS.muted)
                }
                Text(item.mean.text).font(DS.text(15)).foregroundColor(DS.muted)
                HStack(spacing: 10) {
                    listenButton(t("common.listen"), "speaker.wave.2.fill") { A1Speaker.shared.say(item.de) }
                    listenButton(t("speak.slow"), "tortoise.fill") { A1Speaker.shared.say(item.de, slow: true) }
                    Spacer(minLength: 0)
                    Button { withAnimation { useHints.toggle() } } label: {
                        Image(systemName: useHints ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(useHints ? DS.goldDeep : DS.muted)
                            .frame(width: 34, height: 34)
                            .background(useHints ? DS.gold.opacity(0.2) : DS.chip, in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(useHints ? t("speak.hintOn") : t("speak.hintOff"))
                }
                .padding(.top, 4)
                if useHints {
                    Label(t("speak.hintNote"), systemImage: "lightbulb.fill")
                        .font(DS.text(12)).foregroundColor(DS.goldDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            if listener.listening {
                Text(listener.transcript.isEmpty ? t("speak.listening") : listener.transcript)
                    .font(DS.text(16)).foregroundColor(DS.muted).multilineTextAlignment(.center)
                    .frame(minHeight: 44)
            } else if let result {
                feedback(result)
            } else {
                Text(startFailed ? t("speak.unavailable") : t("speak.tapToSpeak"))
                    .font(DS.text(15, .medium)).foregroundColor(DS.muted).frame(minHeight: 44)
            }

            MicButton(listener: listener) { toggle(item) }

            if result != nil && !listener.listening {
                HStack(spacing: 10) {
                    Button(t("speak.again")) { withAnimation { result = nil } ; toggle(item) }
                        .buttonStyle(SpeakPrimaryButton(color: DS.chip, foreground: DS.ink))
                    Button(t("speak.next")) { next() }
                        .buttonStyle(SpeakPrimaryButton())
                }
            } else if !listener.listening {
                Button(t("speak.skip")) { next() }
                    .font(DS.text(14, .semibold)).foregroundColor(DS.muted)
            }
        }
    }

    private func listenButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(DS.text(13, .semibold))
                .foregroundColor(DS.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(DS.chip, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func feedback(_ result: SpeechScore.Result) -> some View {
        let (message, color): (String, Color) = result.heard.isEmpty ? (t("speak.nothing"), DS.muted)
            : result.score >= 85 ? (t("speak.great"), DS.success)
            : result.score >= 60 ? (t("speak.good"), DS.goldDeep)
            : (t("speak.retry"), DS.error)
        return VStack(spacing: 6) {
            if !result.heard.isEmpty {
                Text(t("speak.score", result.score)).font(.system(size: 30, weight: .heavy)).foregroundColor(color)
            }
            Text(message).font(DS.text(16, .semibold)).foregroundColor(color).multilineTextAlignment(.center)
            if !result.heard.isEmpty {
                Text(t("speak.heard") + " " + result.heard).font(DS.text(13)).foregroundColor(DS.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(minHeight: 44)
    }

    private func toggle(_ item: A1Example) {
        if listener.listening {
            listener.stop()
            return
        }
        withAnimation { result = nil }
        let hints = useHints ? SpeechScore.split(item.de).map { a1Core($0) } : []
        startFailed = !listener.start(hints: hints, pause: 1.6, maxSeconds: 15) { heard in
            score(item, heard)
        }
    }

    private func score(_ item: A1Example, _ heard: String) {
        let check = SpeechScore.check(target: item.de, heard: heard, unsure: listener.unsureWords)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { result = check }
        guard !heard.isEmpty else { return }
        let before = best[index] ?? 0
        best[index] = max(before, check.score)
        if check.score >= 70 && before < 70 {
            StreakStore.shared.record()
            StreakStore.shared.addXP(XP.correct)
            xp += XP.correct
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else if check.score < 60 {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func next() {
        listener.cancel()
        result = nil
        if index + 1 < items.count {
            index += 1
        } else {
            finished = true
            onFinish?()
        }
    }

    private var summary: some View {
        let scores = Array(best.values)
        let average = scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
        return VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundColor(DS.gold).padding(.top, 30)
            Text(t("speak.done")).font(DS.display(32)).foregroundColor(DS.ink)
            Text(t("speak.average", average)).font(DS.text(18, .semibold)).foregroundColor(DS.muted)
            if xp > 0 {
                Text("+\(xp) XP").font(.system(size: 22, weight: .heavy)).foregroundColor(DS.goldDeep)
            }
            Button(t("speak.newRound")) {
                items = SpeakingBank.sentences(model.content, count: count)
                index = 0
                best = [:]
                xp = 0
                finished = false
            }
            .buttonStyle(SpeakPrimaryButton())
            .padding(.top, 10)
            Button(t("common.done")) { dismiss() }
                .buttonStyle(SpeakPrimaryButton(color: DS.chip, foreground: DS.ink))
        }
    }
}

// MARK: - Speaking task

struct SpeakTaskView: View {
    let task: SpeakingTask
    /// Mock exam: points covered, points in the task and the score in percent, once, when an answer is finished
    /// (after Lina's rating where the phone has her).
    var onFinish: ((Int, Int, Int) -> Void)? = nil
    @StateObject private var listener = SpeechListener()
    @State private var score: TaskScore?
    @State private var rating = false
    @State private var answer = ""
    @State private var seconds = 0
    @State private var done = false
    @State private var earned = 0
    @State private var startFailed = false
    /// Same switch as in repeat-after-me: off = no hint for the recogniser (honest), on = it expects the task's phrases.
    @AppStorage("speak.useHints") private var useHints = false
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var text: String { listener.listening ? listener.transcript : answer }

    private func covered(_ point: SpeakingPoint) -> Bool { SpeechScore.mentions(text, point.keys) }
    private var coveredCount: Int { task.points.filter(covered).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title.text).font(.subheadline.weight(.semibold)).foregroundColor(.white.opacity(0.85))
                    Text(task.prompt).font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(task.help.text).font(.footnote).foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Label(t("speak.timeHint", task.seconds), systemImage: "timer")
                        Spacer()
                        Button { withAnimation { useHints.toggle() } } label: {
                            Image(systemName: useHints ? "lightbulb.fill" : "lightbulb")
                                .foregroundColor(useHints ? DS.onGold : .white)
                                .frame(width: 34, height: 34)
                                .background(useHints ? DS.gold : Color.white.opacity(0.2), in: Circle())
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(useHints ? t("speak.hintOn") : t("speak.hintOff"))
                        Button { A1Speaker.shared.say(task.prompt) } label: {
                            Image(systemName: "speaker.wave.2.fill").foregroundColor(DS.onGold)
                                .frame(width: 34, height: 34).background(DS.gold, in: Circle())
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(t("common.listen"))
                    }
                    .font(.caption.weight(.semibold)).foregroundColor(.white.opacity(0.9))
                    .padding(.top, 2)
                    if useHints {
                        Label(t("speak.hintNote"), systemImage: "lightbulb.fill")
                            .font(.caption).foregroundColor(.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .background(SpeakStyle.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.top, 4)

                if listener.access != .granted {
                    SpeakAccessView(listener: listener)
                } else {
                    checklist
                    recorder
                    if done, let score { ScoreBreakdownView(score: score, busy: rating) }
                    if done { results }
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 30)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("speak.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { listener.refreshAccess() }
        .onDisappear {
            listener.cancel()
            A1Speaker.shared.stop()
        }
        .onReceive(clock) { _ in if listener.listening { seconds += 1 } }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("speak.points")).font(.system(size: 17, weight: .bold)).foregroundColor(DS.ink)
                Spacer()
                Text("\(coveredCount)/\(task.points.count)").font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundColor(coveredCount == task.points.count ? DS.success : DS.muted)
            }
            ForEach(Array(task.points.enumerated()), id: \.offset) { _, point in
                let ok = covered(point)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(ok ? DS.success : DS.hairline)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(point.label.text).font(DS.text(15, .semibold)).foregroundColor(DS.ink)
                        Text(point.say).font(DS.text(13)).italic().foregroundColor(DS.muted)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: ok)
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recorder: some View {
        VStack(spacing: 10) {
            if listener.listening {
                Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                    .font(.system(size: 22, weight: .heavy).monospacedDigit())
                    .foregroundColor(seconds >= task.seconds ? DS.success : DS.ink)
                Text(listener.transcript.isEmpty ? t("speak.listening") : listener.transcript)
                    .font(DS.text(15)).foregroundColor(DS.muted).multilineTextAlignment(.center)
            } else if !done {
                Text(startFailed ? t("speak.unavailable") : t("speak.taskStart")).font(DS.text(15, .medium))
                    .foregroundColor(DS.muted).multilineTextAlignment(.center)
            }
            MicButton(listener: listener) { toggle() }
        }
        .frame(maxWidth: .infinity)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(t("speak.covered", coveredCount, task.points.count)).font(DS.text(16, .bold))
                    .foregroundColor(coveredCount == task.points.count ? DS.success : DS.ink)
                Spacer()
                if earned > 0 { Text("+\(earned) XP").font(.system(size: 16, weight: .heavy)).foregroundColor(DS.goldDeep) }
            }
            if !answer.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("speak.yourText")).font(.caption.weight(.bold)).foregroundColor(DS.muted).textCase(.uppercase)
                    Text(answer).font(DS.text(15)).foregroundColor(DS.ink)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(t("speak.sample")).font(.caption.weight(.bold)).foregroundColor(DS.muted).textCase(.uppercase)
                    Spacer()
                    Button { A1Speaker.shared.readSample(task.sample) } label: {
                        Label(t("speak.listenSample"), systemImage: "speaker.wave.2.fill").font(DS.text(13, .semibold))
                    }
                }
                Text(task.sample).font(DS.text(15)).foregroundColor(DS.ink)
            }
            .padding(14)
            .background(DS.chip, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func toggle() {
        if listener.listening {
            listener.stop()
            return
        }
        answer = ""
        seconds = 0
        done = false
        earned = 0
        score = nil
        let hints = useHints ? task.points.map(\.say) : []
        startFailed = !listener.start(hints: hints, pause: 5, maxSeconds: Double(max(60, task.seconds + 30))) { heard in
            finish(heard)
        }
    }

    private func finish(_ heard: String) {
        answer = heard
        withAnimation { done = true }
        let count = task.points.filter { SpeechScore.mentions(heard, $0.keys) }.count
        let words = SpeechScore.split(heard).count
        let spokenFor = seconds
        let unsure = listener.unsureWords
        let rules = TaskScorer.speaking(task, heard: heard, seconds: spokenFor, unsure: unsure)
        score = rules
        if LinaAI.isAvailable && words >= 5 {
            rating = true
            Task {
                let result = await LinaAI.rate(task: task.prompt, points: task.points.map { $0.label.values["en"] ?? $0.say },
                                               text: heard, level: task.level, spoken: true)
                await MainActor.run {
                    rating = false
                    if let result {
                        withAnimation {
                            score = TaskScorer.speaking(task, heard: heard, seconds: spokenFor, unsure: unsure, rating: result)
                        }
                    }
                    onFinish?(words >= 5 ? count : 0, task.points.count, score?.percent ?? rules.percent)
                }
            }
        } else {
            onFinish?(words >= 5 ? count : 0, task.points.count, rules.percent)
        }
        guard words >= 5 else { return }
        let previous = SpeakingBank.best(task.id) ?? 0
        // XP for every point covered, once per point and task; a bonus for a full answer.
        let points = max(0, count - previous) * XP.correct
        let bonus = count == task.points.count && previous < task.points.count ? XP.perfectBonus : 0
        earned = points + bonus
        SpeakingBank.save(task.id, covered: count)
        StreakStore.shared.record()
        if earned > 0 {
            StreakStore.shared.addXP(earned)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
