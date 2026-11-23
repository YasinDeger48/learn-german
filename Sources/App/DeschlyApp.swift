import SwiftUI

@main
struct DeschlyApp: App {
    @StateObject private var a1 = A1Model()
    @StateObject private var daily = DailyModel()
    @ObservedObject private var localizer = Localizer.shared
    @Environment(\.scenePhase) private var scenePhase

    private let lessons: [Lesson] = Bundled.decode([Lesson].self, "lessons") ?? []

    var body: some Scene {
        WindowGroup {
            Group {
                if localizer.hasChosen {
                    RootView(lessons: lessons)
                } else {
                    OnboardingView()
                }
            }
            // Rebuild every screen in the new language.
            .id(localizer.language)
            .environmentObject(a1)
            .environmentObject(daily)
            .environmentObject(localizer)
            .tint(DS.accent)
            .onChange(of: scenePhase) { phase in
                if phase == .active { Reminders.refresh(daily) }
            }
        }
    }
}

/// Screens outside the A1 practice area.
enum AppRoute: Hashable {
    case reading(String)
    case readingQuiz(String)
    case practice(String)
}

enum AppTab: Int, CaseIterable {
    case today, levels, reading, videos, settings

    var titleKey: String {
        switch self {
        case .today: return "tab.today"
        case .levels: return "tab.levels"
        case .reading: return "tab.reading"
        case .videos: return "tab.videos"
        case .settings: return "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .levels: return "chart.bar"
        case .reading: return "book"
        case .videos: return "play.rectangle"
        case .settings: return "gearshape"
        }
    }
}

/// Standard iOS tab bar; every tab has its own navigation stack.
struct RootView: View {
    let lessons: [Lesson]
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

            NavigationStack { LessonsView(lessons: lessons) }
                .tabItem { Label(t(AppTab.videos.titleKey), systemImage: AppTab.videos.icon) }
                .tag(AppTab.videos)

            NavigationStack { SettingsView() }
                .tabItem { Label(t(AppTab.settings.titleKey), systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
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
    let route: AppRoute

    var body: some View {
        switch route {
        case .reading(let id):
            if let text = daily.text(id: id) { DailyReadingView(text: text) }
        case .readingQuiz(let id):
            if let text = daily.text(id: id) {
                A1QuizView(title: text.title, onFinish: { correct, total in
                    daily.saveQuiz(text, correct: correct, total: total)
                }) {
                    ReadingQuiz.questions(for: text, words: a1.content?.words ?? [])
                }
            }
        case .practice(let level):
            if level == "A1" { PracticeHomeView() } else { ComingSoonView(level: level) }
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
