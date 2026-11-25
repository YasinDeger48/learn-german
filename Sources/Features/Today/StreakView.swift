import SwiftUI
import UIKit

/// The flame in the Today toolbar: streak number, orange when today is done, grey while today is open.
struct StreakButton: View {
    @ObservedObject private var streak = StreakStore.shared
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundColor(streak.activeToday ? .orange : Color(UIColor.tertiaryLabel))
                Text("\(streak.current)").font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundColor(DS.ink)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: streak.current)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(streak.atRisk ? Color.orange.opacity(0.15) : DS.chip, in: Capsule())
        }
        .accessibilityLabel(t("today.streak", streak.current))
        .accessibilityHint(t("streak.hint"))
    }
}

/// Streak details: today's state, this week, the last weeks, best streak, and a way to keep it.
struct StreakView: View {
    @ObservedObject private var streak = StreakStore.shared
    @EnvironmentObject private var daily: DailyModel
    @Environment(\.dismiss) private var dismiss
    /// Opens a learning screen (closes the sheet first).
    let open: (AppRoute) -> Void

    private let dayLetters: [String] = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]   // Monday first
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    thisWeek
                    stats
                    freezeCard
                    calendarCard
                    actions
                }
                .padding(16)
            }
            .background(DS.ground.ignoresSafeArea())
            .navigationTitle(t("streak.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(t("common.done")) { dismiss() } }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(streak.activeToday ? Color.orange.opacity(0.16) : DS.chip).frame(width: 120, height: 120)
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(streak.activeToday
                                     ? AnyShapeStyle(LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom))
                                     : AnyShapeStyle(Color(UIColor.tertiaryLabel)))
            }
            Text(t("today.streak", streak.current)).font(DS.display(30))
            Text(statusLine)
                .font(.subheadline)
                .foregroundColor(streak.atRisk ? .orange : DS.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(.top, 8)
    }

    private var statusLine: String {
        if streak.activeToday { return t("streak.doneToday") }
        if streak.atRisk {
            let minutes = Int(Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400).timeIntervalSinceNow / 60)
            return t("streak.atRisk", minutes / 60, minutes % 60)
        }
        return t("streak.start")
    }

    private var thisWeek: some View {
        let week = streak.weeks(1).first ?? []
        let today = Calendar.current.startOfDay(for: Date())
        return HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let active = streak.isActive(day)
                let frozen = !active && streak.isFrozen(day)
                let isToday = Calendar.current.isDate(day, inSameDayAs: today)
                VStack(spacing: 6) {
                    Text(dayLetters[index]).font(.caption.weight(.semibold)).foregroundColor(isToday ? DS.ink : DS.muted)
                    ZStack {
                        Circle()
                            .fill(active ? Color.orange : (frozen ? Self.ice : (day > today ? Color.clear : DS.chip)))
                            .frame(width: 34, height: 34)
                        if frozen {
                            Image(systemName: "snowflake").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        }
                        if isToday && !active {
                            Circle().stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [4, 3])).frame(width: 34, height: 34)
                        }
                        if active {
                            Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide)) + (active ? ", ✓" : ""))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var stats: some View {
        HStack(spacing: 10) {
            tile("\(streak.best)", t("streak.best"), "trophy.fill", DS.goldDeep)
            tile("\(streak.totalDays)", t("streak.totalDays"), "calendar", DS.accent)
            tile("\(streak.actions(on: Date()))", t("streak.todayActions"), "checkmark.circle.fill", DS.success)
        }
    }

    static let ice = Color(red: 0.36, green: 0.64, blue: 0.92)

    /// Streak freezes: how many, what they do, how to get more.
    private var freezeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "snowflake")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Self.ice, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(t("freeze.title", streak.state.freezes, XP.maxFreezes)).font(.headline)
                Text(t("freeze.body")).font(.footnote).foregroundColor(DS.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func tile(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(color)
            Text(value).font(.system(size: 22, weight: .bold)).monospacedDigit()
            Text(label).font(.caption).foregroundColor(DS.muted).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// The last five weeks; darker orange = more questions that day.
    private var calendarCard: some View {
        let weeks = streak.weeks(5)
        let today = Calendar.current.startOfDay(for: Date())
        return VStack(alignment: .leading, spacing: 10) {
            Text(t("streak.lastWeeks")).font(.headline)
            HStack(spacing: 6) {
                ForEach(dayLetters.indices, id: \.self) { i in
                    Text(dayLetters[i]).font(.caption2).foregroundColor(DS.muted).frame(maxWidth: .infinity)
                }
            }
            ForEach(weeks.indices, id: \.self) { w in
                HStack(spacing: 6) {
                    ForEach(weeks[w], id: \.self) { day in
                        let count = streak.actions(on: day)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(day > today ? Color.clear
                                  : (count == 0 ? (streak.isFrozen(day) ? Self.ice : DS.chip) : Color.orange.opacity(intensity(count))))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .overlay {
                                if Calendar.current.isDate(day, inSameDayAs: today) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(DS.ink.opacity(0.5), lineWidth: 1.5)
                                }
                            }
                    }
                }
            }
            HStack(spacing: 6) {
                Text(t("streak.less")).font(.caption2).foregroundColor(DS.muted)
                ForEach([0, 3, 10, 25], id: \.self) { n in
                    RoundedRectangle(cornerRadius: 3).fill(n == 0 ? DS.chip : Color.orange.opacity(intensity(n))).frame(width: 14, height: 14)
                }
                Text(t("streak.more")).font(.caption2).foregroundColor(DS.muted)
            }
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("streak.lastWeeksA11y", streak.totalDays))
    }

    private func intensity(_ count: Int) -> Double {
        switch count {
        case ..<5: return 0.35
        case ..<15: return 0.6
        case ..<30: return 0.8
        default: return 1
        }
    }

    @ViewBuilder private var actions: some View {
        if !streak.activeToday {
            VStack(spacing: 10) {
                if let text = daily.today {
                    Button {
                        dismiss()
                        open(.reading(text.id))
                    } label: {
                        Label(t("streak.readToday"), systemImage: "book.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                Button {
                    dismiss()
                    open(.practice(daily.level))
                } label: {
                    Label(t("streak.practice"), systemImage: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.ink)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        if !daily.remindersOn {
            Button {
                Reminders.requestPermission { granted in daily.remindersOn = granted }
            } label: {
                Label(t("streak.remind"), systemImage: "bell.fill").frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        Text(t("streak.rule")).font(.footnote).foregroundColor(DS.muted).multilineTextAlignment(.center)
    }
}
