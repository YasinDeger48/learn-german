import Combine
import SwiftUI
import UIKit
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
    case allTexts
    case readingHome
    case lesson
    case writing
    case writingTask(String)
    /// ExamModule raw value, for the level that is active (LevelModels.active).
    case module(String)
    case basics
    case examRun
    case certificate(String)
    case certificates
    case badges
    case levels
    case settings
}

/// Tabs follow the exam: today's learning, the four exam modules, the mock exam, and the profile.
enum AppTab: Int, CaseIterable {
    case today, modules, exam, profile

    var titleKey: String {
        switch self {
        case .today: return "tab.today"
        case .modules: return "tab.modules"
        case .exam: return "tab.exam"
        case .profile: return "tab.profile"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .modules: return "square.grid.2x2"
        case .exam: return "checkmark.seal"
        case .profile: return "person.crop.circle"
        }
    }
}

/// Standard iOS tab bar; every tab has its own navigation stack.
struct RootView: View {
    @EnvironmentObject private var pro: ProStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var celebration: Celebration?
    @ObservedObject private var notifications = NotificationHandler.shared
    @State private var goalToast = false
    @State private var tab: AppTab = .today
    @State private var todayPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $todayPath) {
                TodayView(open: { todayPath.append($0) }).appRoutes()
            }
            .tabItem { Label(t(AppTab.today.titleKey), systemImage: AppTab.today.icon) }
            .tag(AppTab.today)

            NavigationStack { ModulesHomeView().appRoutes() }
                .tabItem { Label(t(AppTab.modules.titleKey), systemImage: AppTab.modules.icon) }
                .tag(AppTab.modules)

            NavigationStack { ExamHomeView().appRoutes() }
                .tabItem { Label(t(AppTab.exam.titleKey), systemImage: AppTab.exam.icon) }
                .tag(AppTab.exam)

            NavigationStack(path: $profilePath) {
                ProfileView(open: { route in
                    tab = .today
                    todayPath.append(route)
                }).appRoutes()
            }
            .tabItem { Label(t(AppTab.profile.titleKey), systemImage: AppTab.profile.icon) }
            .tag(AppTab.profile)
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
        // Daily goal reached: a short success haptic and a banner at the top, like system confirmations.
        .onReceive(NotificationCenter.default.publisher(for: StreakStore.goalReached)) { _ in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { goalToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeOut(duration: 0.25)) { goalToast = false }
            }
        }
        .overlay(alignment: .top) {
            if goalToast {
                Label(t("goal.done"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DS.success, in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
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
        case .allTexts:
            AllTextsView()
        case .savedWordsQuiz:
            A1QuizView(title: t("saved.title"), free: true) { daily.savedWordsQuiz() }
        case .practice(let level):
            if levels.hasPractice(level) {
                PracticeHomeView().environmentObject(levels.model(level))
            } else {
                ComingSoonView(level: level)
            }
        case .readingHome:
            ReadingHomeView()
        case .writing:
            WritingHomeView().environmentObject(levels.current)
        case .writingTask(let id):
            if let task = WritingBank.task(id) {
                if task.kind == "form" { WritingFormView(task: task) } else { WritingMessageView(task: task) }
            }
        case .lesson:
            LessonView().environmentObject(levels.hasPractice(daily.level) ? levels.model(daily.level) : levels.a1)
        case .module(let raw):
            if let module = ExamModule(rawValue: raw) { ModuleView(module: module).environmentObject(levels.current) }
        case .basics:
            WordsBasicsView().environmentObject(levels.current)
        case .examRun:
            ExamRunView().environmentObject(levels.current)
        case .certificate(let id):
            if let certificate = ExamStore.certificate(id) { CertificateDetailView(certificate: certificate) }
        case .certificates:
            CertificatesListView()
        case .badges:
            BadgesView()
        case .levels:
            LevelsView()
        case .settings:
            SettingsView()
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
