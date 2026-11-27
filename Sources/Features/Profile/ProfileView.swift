import SwiftUI

/// Profile tab: certificates, badges, streak, levels and settings in one place.
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
                    stat("\(streak.current)", t("profile.streak"), "flame.fill", .orange)
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
                Button { showStreak = true } label: {
                    Label(t("profile.streakCalendar"), systemImage: "calendar")
                }
                .foregroundColor(DS.ink)
            } header: {
                Text(t("profile.achievements"))
            }

            Section {
                NavigationLink(value: AppRoute.myWords) {
                    Label(t("words.title"), systemImage: "character.book.closed.fill")
                }
                NavigationLink(value: A1Route.mistakes) {
                    Label(t("practice.mistakes"), systemImage: "arrow.uturn.backward")
                }
                UnlockGate(feature: .exam) {
                    NavigationLink(value: AppRoute.examHome) {
                        Label(t("tab.exam"), systemImage: "checkmark.seal")
                    }
                }
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
