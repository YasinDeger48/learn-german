import Combine
import SwiftUI
import UserNotifications

@main
struct DeschlyApp: App {
    init() {
        // Must run before any content is read: a new app version starts from its own bundled files.
        ContentStore.clearIfAppChanged()
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
        Reminders.registerCategories()
    }

    @StateObject private var levels = LevelModels()
    @StateObject private var daily = DailyModel()
    @StateObject private var pro = ProStore()
    @ObservedObject private var localizer = Localizer.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if localizer.hasChosen {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            // Rebuild every screen in the new language.
            .id(localizer.language)
            .environmentObject(levels)
            .environmentObject(levels.a1)
            .environmentObject(daily)
            .environmentObject(pro)
            .environmentObject(localizer)
            .tint(DS.accent)
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    Reminders.refresh(daily)
                    ContentUpdater.shared.checkIfDue()
                }
            }
        }
    }
}

/// Screens outside the A1 practice area.
enum AppRoute: Hashable {
    case reading(String)
    case readingQuiz(String)
    case practice(String)
    case savedWords
    case savedWordsQuiz
}

enum AppTab: Int, CaseIterable {
    case today, levels, reading, settings

    var titleKey: String {
        switch self {
        case .today: return "tab.today"
        case .levels: return "tab.levels"
        case .reading: return "tab.reading"
        case .settings: return "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .levels: return "chart.bar"
        case .reading: return "book"
        case .settings: return "gearshape"
        }
    }
}

/// Standard iOS tab bar; every tab has its own navigation stack.
struct RootView: View {
    @EnvironmentObject private var pro: ProStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var celebration: Celebration?
    @ObservedObject private var notifications = NotificationHandler.shared
    @State private var tab: AppTab = .today
    @State private var todayPath = NavigationPath()

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $todayPath) {
                TodayView(open: { todayPath.append($0) }).appRoutes()
            }
            .tabItem { Label(t(AppTab.today.titleKey), systemImage: AppTab.today.icon) }
            .tag(AppTab.today)

            NavigationStack { LevelsView().appRoutes() }
                .tabItem { Label(t(AppTab.levels.titleKey), systemImage: AppTab.levels.icon) }
                .tag(AppTab.levels)

            NavigationStack { ReadingHomeView().appRoutes() }
                .tabItem { Label(t(AppTab.reading.titleKey), systemImage: AppTab.reading.icon) }
                .tag(AppTab.reading)

            NavigationStack { SettingsView() }
                .tabItem { Label(t(AppTab.settings.titleKey), systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
        .onAppear {
            // Consent and ads only for the free version, after onboarding.
            if !pro.isPro { AdsManager.shared.start() }
            checkProgress()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { checkProgress() }
        }
        .sheet(item: $celebration) { CelebrationView(badges: $0.badges) }
        // Taps on notifications: open the daily text or the level's practice on the Today tab.
        .onReceive(notifications.$openTextID.compactMap { $0 }) { id in
            tab = .today
            todayPath = NavigationPath()
            todayPath.append(AppRoute.reading(id))
            notifications.openTextID = nil
        }
        .onReceive(notifications.$openPractice.compactMap { $0 }) { level in
            tab = .today
            todayPath = NavigationPath()
            todayPath.append(AppRoute.practice(level))
            notifications.openPractice = nil
        }
    }

    /// Streak freezes for missed days, then badges earned outside a quiz (shown once).
    private func checkProgress() {
        StreakStore.shared.refreshFreezes(isPro: pro.isPro)
        BadgeStore.shared.refresh()
        let pending = BadgeStore.shared.takePending()
        if !pending.isEmpty && celebration == nil { celebration = Celebration(badges: pending) }
    }
}

extension View {
    func appRoutes() -> some View {
        withA1Routes().navigationDestination(for: AppRoute.self) { AppDestination(route: $0) }
    }
}

struct AppDestination: View {
    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var a1: A1Model
    @EnvironmentObject private var levels: LevelModels
    let route: AppRoute

    var body: some View {
        switch route {
        case .reading(let id):
            if let text = daily.text(id: id) { DailyReadingView(text: text) }
        case .readingQuiz(let id):
            if let text = daily.text(id: id) {
                A1QuizView(title: text.title, free: true, onFinish: { correct, total in
                    daily.saveQuiz(text, correct: correct, total: total)
                }) {
                    ReadingQuiz.questions(for: text, words: a1.content?.words ?? [])
                }
            }
        case .savedWords:
            SavedWordsView()
        case .savedWordsQuiz:
            A1QuizView(title: t("saved.title"), free: true) { daily.savedWordsQuiz() }
        case .practice(let level):
            if levels.hasPractice(level) {
                PracticeHomeView().environmentObject(levels.model(level))
            } else {
                ComingSoonView(level: level)
            }
        }
    }
}

struct ComingSoonView: View {
    let level: String

    var body: some View {
        VStack(spacing: 18) {
            LinaAvatar(size: 110)
            Text(level).font(DS.display(56))
            Text(t("levels.soonTitle")).font(DS.display(22, heavy: false)).multilineTextAlignment(.center)
            Text(t("levels.soonText")).font(DS.text(15)).foregroundColor(DS.muted).multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .deschlyPage()
    }
}
