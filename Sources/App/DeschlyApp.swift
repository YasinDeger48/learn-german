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
            .tint(DS.ink)
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
    case today, levels, reading, videos

    var titleKey: String {
        switch self {
        case .today: return "tab.today"
        case .levels: return "tab.levels"
        case .reading: return "tab.reading"
        case .videos: return "tab.videos"
        }
    }
}

struct RootView: View {
    let lessons: [Lesson]
    @State private var tab: AppTab = .today
    @State private var paths: [AppTab: NavigationPath] = [:]

    private func path(_ tab: AppTab) -> Binding<NavigationPath> {
        Binding(get: { paths[tab] ?? NavigationPath() }, set: { paths[tab] = $0 })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                stack(.today) { TodayView(open: open) }
                stack(.levels) { LevelsView() }
                stack(.reading) { ReadingHomeView() }
                stack(.videos) { LessonsView(lessons: lessons) }
            }
            if (paths[tab] ?? NavigationPath()).isEmpty {
                FloatingTabBar(selection: $tab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: (paths[tab] ?? NavigationPath()).isEmpty)
    }

    private func stack<Content: View>(_ tab: AppTab, @ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack(path: path(tab)) {
            content()
                .withA1Routes()
                .navigationDestination(for: AppRoute.self) { AppDestination(route: $0) }
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(tab)
    }

    /// Lets the Today screen jump into other routes in its own stack.
    private func open(_ route: AppRoute) {
        paths[.today, default: NavigationPath()].append(route)
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

/// The black floating pill from the mockup.
struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { item in
                let active = item == selection
                Button {
                    selection = item
                } label: {
                    Text(t(item.titleKey))
                        .font(DS.text(14, active ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(active ? DS.ink : DS.onNightMuted)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(active ? DS.ground : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(8)
        .background(DS.night, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .padding(.horizontal, DS.gutter)
        .padding(.bottom, 8)
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
