import SwiftUI

/// Profile tab: certificates, badges, levels and settings. Every other screen has its one place elsewhere
/// (mistakes and the exam in Practice). The streak calendar opens from the streak itself (here and on Today).
struct ProfileView: View {
    @EnvironmentObject private var daily: DailyModel
    @ObservedObject private var streak = StreakStore.shared
    @State private var certificates = ExamStore.certificates()
    @State private var showStreak = false
    let open: (AppRoute) -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Button { showStreak = true } label: {
                        stat("\(streak.current)", t("profile.streak"), "flame.fill", .orange)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityHint(t("profile.streakCalendar"))
                    stat("\(streak.state.totalXP)", "XP", "bolt.fill", DS.goldDeep)
                    stat(daily.level, t("profile.level"), "graduationcap.fill", DS.accent)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                NavigationLink(value: AppRoute.certificates) {
                    Label {
                        HStack {
                            Text(t("cert.mine"))
                            Spacer()
                            Text("\(certificates.count)").foregroundColor(DS.muted)
                        }
                    } icon: {
                        Image(systemName: "rosette").foregroundColor(DS.goldDeep)
                    }
                }
                NavigationLink(value: AppRoute.badges) {
                    Label(t("profile.badges"), systemImage: "medal.fill")
                }
            } header: {
                Text(t("profile.achievements"))
            }

            Section {
                NavigationLink(value: AppRoute.levels) {
                    Label(t("tab.levels"), systemImage: "chart.bar")
                }
                NavigationLink(value: AppRoute.settings) {
                    Label(t("tab.settings"), systemImage: "gearshape")
                }
            }
        }
        .navigationTitle(t("tab.profile"))
        .sheet(isPresented: $showStreak) {
            StreakView(open: { route in
                showStreak = false
                open(route)
            })
            .environmentObject(daily)
            .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: ExamStore.changed)) { _ in certificates = ExamStore.certificates() }
    }

    private func stat(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(DS.ink)
            Text(label).font(.caption).foregroundColor(DS.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
