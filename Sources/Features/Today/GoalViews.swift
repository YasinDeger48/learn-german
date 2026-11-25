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
