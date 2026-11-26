import SwiftUI
import UIKit

/// A ring that fills toward a goal.
struct GoalRing<Center: View>: View {
    var progress: Double
    var size: CGFloat = 86
    var lineWidth: CGFloat = 10
    var color: Color = DS.accent
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle().stroke(Color(UIColor.systemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            center()
        }
        .frame(width: size, height: size)
    }
}

/// Today's goal in the toolbar: a small ring that fills with today's XP ("30/50"); when the goal is reached,
/// a green tick with today's XP. Tapping it opens the badges page, which starts with the daily goal card
/// (total XP and the level are there too). Design "A · Halka".
struct XPChip: View {
    @ObservedObject private var store = StreakStore.shared

    var body: some View {
        let done = store.goalReachedToday
        HStack(spacing: 6) {
            ZStack {
                if done {
                    Circle().fill(DS.success)
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                } else {
                    Circle().stroke(DS.hairline, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(0.001, store.goalProgress))
                        .stroke(DS.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: store.goalProgress)
                }
            }
            .frame(width: 18, height: 18)
            Text(done ? "\(store.xpToday) XP" : "\(store.xpToday)/\(store.goal)")
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundColor(done ? DS.success : DS.ink)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: store.xpToday)
        }
        .padding(.leading, 7)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background(done ? DS.success.opacity(0.14) : DS.chip, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("goal.title") + ": \(store.xpToday) / \(store.goal) XP")
    }
}

/// Today's goal: ring with today's XP, what is left, and a tap to change the goal.
struct DailyGoalCard: View {
    @ObservedObject private var store = StreakStore.shared
    @State private var choosing = false

    var body: some View {
        Button {
            choosing = true
        } label: {
            HStack(spacing: 16) {
                GoalRing(progress: store.goalProgress, color: store.goalReachedToday ? DS.success : DS.accent) {
                    if store.goalReachedToday {
                        Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy)).foregroundColor(DS.success)
                    } else {
                        VStack(spacing: 0) {
                            Text("\(store.xpToday)").font(.system(size: 20, weight: .heavy)).monospacedDigit()
                                .contentTransition(.numericText())
                                .animation(.easeOut(duration: 0.3), value: store.xpToday)
                            Text("/ \(store.goal) XP").font(.caption2).foregroundColor(DS.muted)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("goal.title").uppercased()).font(.caption.weight(.semibold)).foregroundColor(DS.muted)
                    Text(store.goalReachedToday ? t("goal.done") : t("goal.left", store.goal - store.xpToday))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DS.ink)
                        .multilineTextAlignment(.leading)
                    Text(store.goalReachedToday ? t("goal.doneSub", store.xpToday) : t("goal.minutes", max(1, (store.goal - store.xpToday + 8) / 9)))
                        .font(.footnote)
                        .foregroundColor(DS.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityHint(t("goal.changeHint"))
        .confirmationDialog(t("goal.choose"), isPresented: $choosing, titleVisibility: .visible) {
            ForEach(XP.goals, id: \.self) { goal in
                Button(t("goal.option.\(goal)", goal) + (goal == store.goal ? " ✓" : "")) { store.setGoal(goal) }
            }
        }
    }
}

/// The word in the island: a noun with an example from the learner's level. A new one each time Today is shown
/// (`round` changes: the app comes back, the user returns to Today), never the same word twice in a row; within
/// one round it stays the same while the page redraws.
enum WordOfDay {
    private static let idKey = "wordOfDay.id"
    private static var roundKey: String?
    private static var roundID: String?

    static func pick(from words: [A1Word], level: String, round: Int) -> A1Word? {
        let nouns = words.filter { $0.isNoun && !$0.ex.isEmpty && $0.theme != A1BankBuilder.coreTheme }
        guard !nouns.isEmpty else { return nil }
        let key = "\(level)#\(round)"
        if roundKey == key, let word = nouns.first(where: { "\(level)-\($0.id)" == roundID }) {
            return word
        }
        let last = UserDefaults.standard.string(forKey: idKey)
        let choices = nouns.count > 1 ? nouns.filter { "\(level)-\($0.id)" != last } : nouns
        guard let word = choices.randomElement() else { return nil }
        roundKey = key
        roundID = "\(level)-\(word.id)"
        UserDefaults.standard.set(roundID, forKey: idKey)
        return word
    }
}

/// The islands on Today (today's text, word of the day), stacked at the bottom left. Only one is open at a time:
/// opening one folds the other into its pill, so they never cover each other. Not saved on purpose: every app
/// start shows today's text open and the word as a pill again.
final class TodayIslands: ObservableObject {
    enum Mode { case open, pill, closed }
    enum Island { case text, word }

    static let shared = TodayIslands()
    @Published var text: Mode = .open
    @Published var word: Mode = .pill

    func mode(_ island: Island) -> Mode { island == .text ? text : word }

    func set(_ island: Island, _ mode: Mode) {
        if mode == .open {
            if island == .text, word == .open { word = .pill }
            if island == .word, text == .open { text = .pill }
        }
        if island == .text { text = mode } else { word = mode }
    }
}

/// A black island: a pill tucked into the left edge, or the open card with ⌄ (fold) and ✕ (close until the next start).
struct TodayIsland<Pill: View, Card: View>: View {
    let island: TodayIslands.Island
    let title: String
    @ViewBuilder var pill: () -> Pill
    @ViewBuilder var card: () -> Card
    @ObservedObject private var state = TodayIslands.shared
    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.8)

    var body: some View {
        let mode = state.mode(island)
        if mode != .closed {
            Group {
                if mode == .open {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                            Spacer()
                            roundButton("chevron.down") { state.set(island, .pill) }
                            roundButton("xmark") { state.set(island, .closed) }
                        }
                        card()
                    }
                    .padding(16)
                    .frame(width: 300)
                } else {
                    pill()
                        .padding(.vertical, 10)
                        .padding(.leading, 24)
                        .padding(.trailing, 12)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(spring) { state.set(island, .open) } }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(title)
                }
            }
            .background(Color.black, in: RoundedRectangle(cornerRadius: mode == .open ? 28 : 22, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: mode == .open ? 18 : 8, y: 5)
            .offset(x: mode == .open ? 12 : -14)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    private func roundButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(spring) { action() } } label: {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                .frame(width: 28, height: 28).background(Color.white.opacity(0.12), in: Circle())
                .frame(width: 44, height: 44)  // the circle stays small, the finger target is 44 pt
                .contentShape(Rectangle())
        }
        .accessibilityLabel(t("common.close"))
    }
}

/// The word of the day: the word, its meaning and an example with a listen button.
struct WordIsland: View {
    let word: A1Word

    var body: some View {
        TodayIsland(island: .word, title: t("today.wordOfDay")) {
            HStack(spacing: 6) {
                Image(systemName: "character.book.closed.fill").font(.system(size: 14, weight: .bold)).foregroundColor(DS.gold)
                Text(word.de).font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
            }
        } card: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if word.isNoun {
                        Text(word.type).font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(a1ArticleColor(word.type), in: Capsule())
                    }
                    Text(word.de).font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
                }
                Text(a1PronLead(word.pron) + word.mean.text).font(.system(size: 14, weight: .semibold)).foregroundColor(DS.gold)
                    .fixedSize(horizontal: false, vertical: true)
                if let example = word.ex.first {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("„\(example.de)“").font(.system(size: 14)).italic().foregroundColor(.white.opacity(0.9))
                        Text(example.mean.text).font(.footnote).foregroundColor(.white.opacity(0.6))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    A1Speaker.shared.play([A1Line(s: -1, t: word.withArticle)] + word.ex.prefix(1).map { A1Line(s: -1, t: $0.de) })
                } label: {
                    Label(t("common.listen"), systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Today's text: its picture, title and quiz state, and a button to read it.
struct TextIsland: View {
    let text: DailyText
    /// "Quiz 100 %", "Try the quiz again", … (from Today).
    let note: String
    let readLabel: String
    let read: () -> Void

    var body: some View {
        TodayIsland(island: .text, title: t("today.dailyMeta", text.level, text.minutes)) {
            HStack(spacing: 6) {
                Image(systemName: "book.fill").font(.system(size: 14, weight: .bold)).foregroundColor(DS.gold)
                Text(text.title).font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
                    .frame(maxWidth: 190, alignment: .leading)
            }
        } card: {
            VStack(alignment: .leading, spacing: 10) {
                if let cover = Covers.image(text.id) {
                    Image(uiImage: cover).resizable().scaledToFill()
                        .frame(width: 268, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Text(text.title).font(.system(size: 21, weight: .heavy)).foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note).font(.footnote).foregroundColor(.white.opacity(0.7))
                Button(action: read) {
                    HStack(spacing: 8) {
                        Text(readLabel)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.onGold)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// "N reviews due today" on Today: spaced repetition of answered questions. Hidden when nothing is due.
struct ReviewCard: View {
    @ObservedObject var model: A1Model

    var body: some View {
        let due = model.ready ? model.dueReviewIDs.count : 0
        if due > 0 {
            NavigationLink(value: A1Route.review) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 46, height: 46)
                        .background(LinearGradient(colors: [Color(red: 0.55, green: 0.42, blue: 1), Color(red: 0.36, green: 0.25, blue: 0.84)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("review.cardTitle", due)).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                        Text(t("review.cardSub", model.level)).font(.footnote).foregroundColor(DS.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
    }
}
