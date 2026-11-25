import SwiftUI
import UIKit

/// Round badge: gradient when earned, grey with a progress ring when not.
struct BadgeIcon: View {
    let badge: Badge
    var earned: Bool
    var progress: Double = 0
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            if earned {
                Circle().fill(LinearGradient(colors: badge.colors, startPoint: .top, endPoint: .bottom))
            } else {
                Circle().fill(Color(UIColor.systemFill))
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, progress)))
                    .stroke(badge.colors.last ?? DS.accent, style: StrokeStyle(lineWidth: max(2, size * 0.05), lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: badge.icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(earned ? .white : Color(UIColor.tertiaryLabel))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// XP level, weekly XP, the next goal and every badge.
struct BadgesView: View {
    @ObservedObject private var streak = StreakStore.shared
    @ObservedObject private var badges = BadgeStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let values = Dictionary(uniqueKeysWithValues: [Badge.Kind.welcome, .streak, .xp, .correct, .perfect, .reading, .goal]
            .map { ($0, badges.value($0)) })
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if badges.onlyWelcome { waitingCard }
                    levelCard
                    if let next = badges.nextGoal {
                        HStack(spacing: 12) {
                            BadgeIcon(badge: next.badge, earned: false, progress: Double(next.value) / Double(max(1, next.badge.target)), size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("badges.next")).font(.caption.weight(.semibold)).foregroundColor(DS.muted)
                                Text(next.badge.title).font(.headline)
                                Text(t("badges.progress", min(next.value, next.badge.target), next.badge.target))
                                    .font(.footnote).foregroundColor(DS.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    weekCard
                    Text(t("badges.count", badges.earned.count, BadgeStore.all.count)).font(.headline).padding(.top, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(BadgeStore.all) { badge in
                            let earned = badges.isEarned(badge)
                            let value = values[badge.kind] ?? 0
                            VStack(spacing: 8) {
                                BadgeIcon(badge: badge, earned: earned, progress: Double(value) / Double(max(1, badge.target)))
                                Text(badge.title).font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(earned ? DS.ink : DS.muted)
                                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.85)
                                if !earned {
                                    Text("\(min(value, badge.target)) / \(badge.target)").font(.caption2.monospacedDigit()).foregroundColor(DS.muted)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 122)
                            .padding(.vertical, 8)
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(badge.title + ", " + (earned ? t("badges.earned") : t("badges.progress", min(value, badge.target), badge.target)))
                        }
                    }
                }
                .padding(16)
            }
            .background(DS.ground.ignoresSafeArea())
            .navigationTitle(t("badges.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(t("common.done")) { dismiss() } }
            }
            .onAppear { badges.refresh() }
        }
    }

    private var welcome: Badge { Badge(kind: .welcome, target: 1) }

    /// Only the welcome badge so far: curious Lina shows it and waits with the user for the next one.
    private var waitingCard: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                LinaAvatar(size: 76, mood: .curious)
                    .clipShape(Circle())
                BadgeIcon(badge: welcome, earned: true, size: 30)
                    .overlay(Circle().stroke(DS.surface, lineWidth: 3))
                    .offset(x: 4, y: 4)
            }
            VStack(alignment: .leading, spacing: 4) {
                if badges.isEarned(welcome) {
                    Label(t("badges.firstEarned", welcome.title), systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(DS.success)
                }
                Text(t("badges.emptyTitle")).font(DS.display(20)).foregroundColor(DS.ink)
                Text(t("badges.emptySub")).font(.subheadline).foregroundColor(DS.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(LinearGradient(colors: [DS.gold.opacity(0.22), DS.gold.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var levelCard: some View {
        let range = streak.xpLevelRange
        let span = max(1, range.end - range.start)
        let inLevel = min(span, max(0, streak.state.totalXP - range.start))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(t("badges.level", streak.xpLevel)).font(.system(size: 20, weight: .heavy))
                Spacer()
                Text("\(streak.state.totalXP.formatted()) / \(range.end.formatted()) XP").font(.footnote.monospacedDigit()).foregroundColor(DS.muted)
            }
            ProgressView(value: Double(inLevel), total: Double(span)).tint(DS.accent)
            Text(t("badges.toNext", max(0, range.end - streak.state.totalXP), streak.xpLevel + 1)).font(.footnote).foregroundColor(DS.muted)
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// This week's XP per day, Monday first.
    private var weekCard: some View {
        let week = streak.weeks(1).first ?? []
        let today = Calendar.current.startOfDay(for: Date())
        let values = week.map { streak.xp(on: $0) }
        let top = max(streak.goal, values.max() ?? 0, 1)
        let thisWeek = values.reduce(0, +)
        var lastWeekTotal = 0
        if let first = week.first {
            for back in 1...7 {
                if let day = Calendar.current.date(byAdding: .day, value: -back, to: first) { lastWeekTotal += streak.xp(on: day) }
            }
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text(t("badges.week")).font(.headline)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                    let isToday = Calendar.current.isDate(day, inSameDayAs: today)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isToday ? DS.accent : (values[index] > 0 ? DS.accent.opacity(0.35) : Color(UIColor.systemFill)))
                            .frame(height: max(6, 70 * CGFloat(values[index]) / CGFloat(top)))
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundColor(DS.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 92, alignment: .bottom)
            Text(lastWeekTotal > 0
                 ? t("badges.weekCompare", thisWeek, Int((Double(thisWeek - lastWeekTotal) / Double(lastWeekTotal) * 100).rounded()))
                 : t("badges.weekTotal", thisWeek))
                .font(.footnote).foregroundColor(DS.muted)
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Shown once when something new was earned: a streak milestone gets the big flame, other badges the badge.
struct CelebrationView: View {
    let badges: [Badge]
    @ObservedObject private var streak = StreakStore.shared
    @Environment(\.dismiss) private var dismiss

    private var milestone: Badge? {
        badges.filter { $0.kind == .streak && BadgeStore.milestones.contains($0.target) }.max { $0.target < $1.target }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)
            if let milestone {
                ZStack(alignment: .bottom) {
                    Circle().fill(RadialGradient(colors: [Color.orange.opacity(0.3), .clear], center: .center, startRadius: 4, endRadius: 90))
                        .frame(width: 180, height: 180)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                        .frame(width: 180, height: 180)
                    Text("\(milestone.target)")
                        .font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 4)
                        .background(DS.night, in: Capsule())
                        .offset(y: 6)
                }
                Text(milestoneTitle(milestone.target)).font(DS.display(32)).multilineTextAlignment(.center)
                Text(t("celebrate.streakBody", milestone.target)).foregroundColor(DS.muted).multilineTextAlignment(.center)
                if streak.state.freezes > 0 {
                    Label(t("celebrate.freezes", streak.state.freezes), systemImage: "snowflake")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(red: 0.1, green: 0.44, blue: 0.76))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(red: 0.89, green: 0.95, blue: 1), in: Capsule())
                }
            } else if let first = badges.first, first.kind == .welcome {
                ZStack(alignment: .bottomTrailing) {
                    LinaAvatar(size: 150, mood: .curious).clipShape(Circle())
                    BadgeIcon(badge: first, earned: true, size: 52)
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                }
                Text("Neues Abzeichen!").font(DS.display(32))
                Text(first.title).font(.title3.weight(.semibold))
                Text(t("badge.welcomeSub")).foregroundColor(DS.muted).multilineTextAlignment(.center)
            } else if let first = badges.first {
                BadgeIcon(badge: first, earned: true, size: 140)
                Text("Neues Abzeichen!").font(DS.display(32))
                Text(first.title).font(.title3.weight(.semibold))
                if first.kind == .welcome {
                    Text(t("badge.welcomeSub")).foregroundColor(DS.muted).multilineTextAlignment(.center)
                }
            }
            let others = badges.filter { $0.id != (milestone ?? badges.first)?.id }
            if !others.isEmpty {
                HStack(spacing: 10) {
                    ForEach(others.prefix(4)) { badge in
                        VStack(spacing: 4) {
                            BadgeIcon(badge: badge, earned: true, size: 44)
                            Text(badge.title).font(.caption2).foregroundColor(DS.muted).lineLimit(2).multilineTextAlignment(.center)
                        }
                        .frame(width: 72)
                    }
                }
            }
            Spacer()
            Button(milestone == nil ? "Super!" : "Weiter so!") { dismiss() }
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(milestone == nil ? DS.accent : Color.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            ShareLink(item: shareText) {
                Label(t("celebrate.share"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(LinearGradient(colors: [milestone == nil ? DS.accent.opacity(0.10) : Color.orange.opacity(0.14), DS.ground],
                                   startPoint: .top, endPoint: .center).ignoresSafeArea())
    }

    private func milestoneTitle(_ days: Int) -> String {
        switch days {
        case 7: return "Eine ganze Woche!"
        case 14: return "Zwei Wochen!"
        case 30: return "Ein ganzer Monat!"
        case 365: return "Ein ganzes Jahr!"
        default: return "\(days) Tage!"
        }
    }

    private var shareText: String {
        if let milestone { return t("celebrate.shareStreak", milestone.target) }
        return t("celebrate.shareBadge", badges.first?.title ?? "")
    }
}

/// Identifiable wrapper for `.sheet(item:)`.
struct Celebration: Identifiable {
    let id = UUID()
    let badges: [Badge]
}
