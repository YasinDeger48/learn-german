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

/// Total XP in the toolbar.
struct XPChip: View {
    @ObservedObject private var store = StreakStore.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").foregroundColor(DS.accent)
            Text(store.state.totalXP.formatted()).font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundColor(DS.ink)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: store.state.totalXP)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DS.accent.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t("xp.total", store.state.totalXP))
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

/// Where the islands on Today are, so they never cover each other. Both islands sit in the same overlay,
/// measured in the coordinate space `IslandLayout.space`. The word island reports its frame; the goal island
/// moves itself above it when they would overlap (also while it is dragged).
final class IslandLayout: ObservableObject {
    static let shared = IslandLayout()
    static let space = "todayIslands"
    /// The word island's frame; .zero when it is closed.
    @Published var wordFrame: CGRect = .zero
}

/// Today's goal as a small black "island" tucked into the screen edge, like the iPhone's Dynamic Island.
/// Tap: it opens into a card (ring, what is left, change the goal); tap outside: it closes.
/// Drag: move it up or down, or across the middle to the other edge. The place is remembered.
/// When the daily goal is reached it opens by itself for a moment.
struct GoalIsland: View {
    @ObservedObject private var store = StreakStore.shared
    /// Top of the island as a share of the available height, and the edge it sits on.
    @AppStorage("goalIsland.y") private var savedY: Double = 0.62
    @AppStorage("goalIsland.left") private var onLeft = false
    @State private var open = false
    @State private var drag: CGSize = .zero
    @State private var choosing = false
    @State private var islandSize: CGSize = .zero
    @ObservedObject private var layout = IslandLayout.shared

    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    private var ringColor: Color { store.goalReachedToday ? DS.success : DS.gold }

    var body: some View {
        GeometryReader { geo in
            let top = islandTop(height: geo.size.height, width: geo.size.width)
            ZStack(alignment: onLeft ? .topLeading : .topTrailing) {
                if open {
                    // Tap anywhere else to close.
                    Color.black.opacity(0.001)
                        .onTapGesture { withAnimation(spring) { open = false } }
                }
                island
                    .background(GeometryReader { g in
                        Color.clear
                            .onAppear { islandSize = g.size }
                            .onChange(of: g.size) { islandSize = $0 }
                    })
                    .offset(x: islandX, y: top)
                    .animation(spring, value: layout.wordFrame)
                    .onTapGesture { withAnimation(spring) { open.toggle() } }
                    .gesture(DragGesture(minimumDistance: 8)
                        .onChanged { value in if !open { drag = value.translation } }
                        .onEnded { value in
                            guard !open else { return }
                            let height: Double = max(1, Double(geo.size.height))
                            let newY: Double = (savedY * height + Double(value.translation.height)) / height
                            let half: CGFloat = geo.size.width / 2
                            let moved: CGFloat = value.translation.width
                            let crossed: Bool = onLeft ? moved > half : moved < -half
                            withAnimation(spring) {
                                savedY = min(max(newY, 0.02), 0.92)
                                if crossed { onLeft.toggle() }
                                drag = .zero
                            }
                        })
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: onLeft ? .topLeading : .topTrailing)
        }
        .confirmationDialog(t("goal.choose"), isPresented: $choosing, titleVisibility: .visible) {
            ForEach(XP.goals, id: \.self) { goal in
                Button(t("goal.option.\(goal)", goal) + (goal == store.goal ? " ✓" : "")) { store.setGoal(goal) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: StreakStore.goalReached)) { _ in
            withAnimation(spring) { open = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation(spring) { open = false } }
        }
    }

    /// Top of the island in the available height: kept on screen, and above the word island when they would overlap.
    private func islandTop(height: CGFloat, width: CGFloat) -> CGFloat {
        let wanted: CGFloat = CGFloat(savedY) * height + (open ? 0 : drag.height)
        let lowest: CGFloat = max(8, height - (open ? 190 : 60))
        let top: CGFloat = min(max(wanted, 8), lowest)
        let word: CGRect = layout.wordFrame
        guard word != .zero, islandSize.width > 0 else { return top }
        let left: CGFloat = onLeft ? islandX : width - islandSize.width + islandX
        let mine = CGRect(x: left, y: top, width: islandSize.width, height: islandSize.height)
        guard mine.intersects(word.insetBy(dx: -8, dy: -8)) else { return top }
        return max(8, word.minY - islandSize.height - 12)
    }

    /// Closed: reaching 14 pt into the edge (and following a drag). Open: 12 pt inside the screen.
    private var islandX: CGFloat {
        if open { return onLeft ? 12 : -12 }
        let tucked: CGFloat = onLeft ? -14 : 14
        return tucked + drag.width
    }

    private var island: some View {
        Group {
            if open { openCard } else { closedPill }
        }
        .background(Color.black, in: RoundedRectangle(cornerRadius: open ? 30 : 22, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: open ? 18 : 8, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(t("goal.changeHint"))
    }

    /// Small: ring and today's XP. The side toward the edge has extra room, since it reaches into the edge.
    private var closedPill: some View {
        HStack(spacing: 7) {
            GoalRing(progress: store.goalProgress, size: 26, lineWidth: 4, color: ringColor) {
                if store.goalReachedToday {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundColor(DS.success)
                }
            }
            Text("\(store.xpToday)").font(.system(size: 15, weight: .heavy)).monospacedDigit().foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: store.xpToday)
        }
        .padding(.vertical, 8)
        .padding(.leading, onLeft ? 24 : 10)
        .padding(.trailing, onLeft ? 10 : 24)
    }

    private var openCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                GoalRing(progress: store.goalProgress, size: 62, lineWidth: 8, color: ringColor) {
                    if store.goalReachedToday {
                        Image(systemName: "checkmark").font(.system(size: 22, weight: .heavy)).foregroundColor(DS.success)
                    } else {
                        Text("\(Int(store.goalProgress * 100))%").font(.system(size: 14, weight: .heavy)).foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("goal.title").uppercased()).font(.caption2.weight(.bold)).foregroundColor(.white.opacity(0.6))
                    Text(store.goalReachedToday ? t("goal.done") : t("goal.left", store.goal - store.xpToday))
                        .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(store.goalReachedToday ? t("goal.doneSub", store.xpToday)
                         : "\(store.xpToday) / \(store.goal) XP · " + t("goal.minutes", max(1, (store.goal - store.xpToday + 8) / 9)))
                        .font(.footnote).foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                choosing = true
            } label: {
                Label(t("goal.change"), systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 300)
    }
}

/// Word of the day: a noun with an example from the learner's level. A new one every day and never
/// yesterday's word again (also when the level changed); the choice is kept for the whole day.
enum WordOfDay {
    private static let dayKey = "wordOfDay.day"
    private static let idKey = "wordOfDay.id"

    static func pick(from words: [A1Word], level: String) -> A1Word? {
        let nouns = words.filter { $0.isNoun && !$0.ex.isEmpty && $0.theme != A1BankBuilder.coreTheme }
        guard !nouns.isEmpty else { return nil }
        let defaults = UserDefaults.standard
        let today = A1Model.dayString(Date())
        let stored = defaults.string(forKey: idKey)
        if defaults.string(forKey: dayKey) == today, let word = nouns.first(where: { "\(level)-\($0.id)" == stored }) {
            return word
        }
        var index = (DailyModel.dayNumber(Date()) * 37 + 11) % nouns.count
        if nouns.count > 1 && "\(level)-\(nouns[index].id)" == stored { index = (index + 1) % nouns.count }
        defaults.set(today, forKey: dayKey)
        defaults.set("\(level)-\(nouns[index].id)", forKey: idKey)
        return nouns[index]
    }
}

/// Open / closed state of the word island. Not saved on purpose: every app start shows the word again, open.
final class WordIslandState: ObservableObject {
    static let shared = WordIslandState()
    @Published var open = true
    @Published var closed = false
}

/// The word of the day as a small black island at the bottom left of Today. Open: the word, its meaning and an
/// example with a listen button; the arrow folds it into a small pill at the edge, the cross closes it until the
/// app starts again.
struct WordIsland: View {
    let word: A1Word
    @ObservedObject private var state = WordIslandState.shared
    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.8)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear
            if !state.closed {
                Group {
                    if state.open { card } else { pill }
                }
                .background(Color.black, in: RoundedRectangle(cornerRadius: state.open ? 28 : 22, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: state.open ? 18 : 8, y: 5)
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { report(g.frame(in: .named(IslandLayout.space))) }
                        .onChange(of: g.frame(in: .named(IslandLayout.space))) { report($0) }
                })
                .offset(x: offsetX)
                .padding(.bottom, 12)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private var offsetX: CGFloat { state.open ? 12 : -14 }

    /// The frame on screen (the measured frame does not include the offset).
    private func report(_ frame: CGRect) {
        IslandLayout.shared.wordFrame = state.closed ? .zero : frame.offsetBy(dx: offsetX, dy: 0)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Image(systemName: "character.book.closed.fill").font(.system(size: 14, weight: .bold)).foregroundColor(DS.gold)
            Text(word.de).font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.leading, 24)
        .padding(.trailing, 12)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(spring) { state.open = true } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(t("today.wordOfDay") + ": " + word.withArticle)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(t("today.wordOfDay").uppercased()).font(.caption2.weight(.bold)).foregroundColor(.white.opacity(0.6))
                Spacer()
                Button { withAnimation(spring) { state.open = false } } label: {
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28).background(Color.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel(t("common.close"))
                Button {
                    withAnimation(spring) { state.closed = true }
                    IslandLayout.shared.wordFrame = .zero
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28).background(Color.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel(t("common.close"))
            }
            .foregroundColor(.white)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(word.type).font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(a1ArticleColor(word.type), in: Capsule())
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
        .padding(16)
        .frame(width: 300)
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
