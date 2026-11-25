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

    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    private var ringColor: Color { store.goalReachedToday ? DS.success : DS.gold }

    var body: some View {
        GeometryReader { geo in
            let top = islandTop(height: geo.size.height)
            ZStack(alignment: onLeft ? .topLeading : .topTrailing) {
                if open {
                    // Tap anywhere else to close.
                    Color.black.opacity(0.001)
                        .onTapGesture { withAnimation(spring) { open = false } }
                }
                island
                    .offset(x: islandX, y: top)
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

    /// Top of the island in the available height, kept on screen.
    private func islandTop(height: CGFloat) -> CGFloat {
        let wanted: CGFloat = CGFloat(savedY) * height + (open ? 0 : drag.height)
        let lowest: CGFloat = max(8, height - (open ? 190 : 60))
        return min(max(wanted, 8), lowest)
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
