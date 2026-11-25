import SwiftUI

/// First launch: Lina greets, asks for the learner's language, finds the level (short test or own choice),
/// then offers the daily reminder.
struct OnboardingView: View {
    enum Step { case language, levelWay, test, result, pick, reminder }

    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var levels: LevelModels
    @State private var language: AppLanguage = AppLanguage.device
    @State private var step = Step.language
    @State private var recommended: String?
    @State private var level = "A1"
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()

    /// Strings for the language being chosen, before the app switches to it.
    private func preview(_ key: String) -> String {
        guard let url = Bundle.main.url(forResource: "strings_\(language.rawValue)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode([String: String].self, from: data) else { return t(key) }
        return table[key] ?? t(key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                LinaAvatar(size: 88)
                VStack(alignment: .leading, spacing: 4) {
                    Wordmark(size: 24)
                    Text("Deutsch lernen, leicht gemacht.").font(DS.text(13)).foregroundColor(DS.muted)
                }
            }
            .padding(.top, 24)

            switch step {
            case .language: languageStep
            case .levelWay: levelWayStep
            case .test:
                PlacementTestView(text: preview) { result in
                    recommended = result
                    level = result
                    step = .result
                }
                .padding(.top, 24)
            case .result: resultStep
            case .pick: pickStep
            case .reminder: reminderStep
            }
        }
        .padding(.horizontal, DS.gutter)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .deschlyPage()
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hallo! Ich bin Lina.")
                .font(DS.display(34))
                .foregroundColor(DS.ink)
                .padding(.top, 28)
            Text(preview("onboarding.ask"))
                .font(DS.text(16))
                .foregroundColor(DS.ink.opacity(0.8))
                .padding(.top, 6)
            // Seven languages: the list scrolls on small phones, the start button stays on screen.
            ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(AppLanguage.offered) { lang in
                    let active = lang == language
                    Button {
                        language = lang
                    } label: {
                        HStack(spacing: 14) {
                            LanguageFlag(language: lang)
                                .frame(width: 34, alignment: .leading)
                            Text(lang.nativeName)
                                .font(DS.text(16, active ? .semibold : .regular))
                                .foregroundColor(active ? DS.onNight : DS.ink)
                            Spacer()
                            if active {
                                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundColor(DS.gold)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .background(active ? DS.night : DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(active ? Color.clear : DS.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
            }
            .padding(.top, 22)
            Spacer(minLength: 12)
            Text(preview("onboarding.changeLater"))
                .font(DS.text(12))
                .foregroundColor(DS.muted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
            Button {
                step = .levelWay
            } label: {
                HStack {
                    Text(preview("onboarding.start"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PillButtonStyle())
        }
    }

    // MARK: Level

    private var levelWayStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(preview("placement.wayTitle"))
                .font(DS.display(30))
                .foregroundColor(DS.ink)
                .padding(.top, 28)
            Text(preview("placement.wayText"))
                .font(DS.text(16))
                .foregroundColor(DS.ink.opacity(0.8))
                .padding(.top, 8)
            VStack(spacing: 10) {
                wayCard(icon: "checklist", color: DS.accent, title: preview("placement.wayTest"), sub: preview("placement.wayTestSub")) {
                    step = .test
                }
                wayCard(icon: "hand.point.up.left.fill", color: .orange, title: preview("placement.wayPick"), sub: preview("placement.wayPickSub")) {
                    recommended = nil
                    step = .pick
                }
                wayCard(icon: "sparkles", color: DS.success, title: preview("placement.wayBeginner"), sub: preview("placement.wayBeginnerSub")) {
                    level = "A1"
                    finishLevel()
                }
            }
            .padding(.top, 22)
            Spacer()
        }
    }

    private func wayCard(icon: String, color: Color, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                    Text(sub).font(.footnote).foregroundColor(DS.muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private var resultStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(preview("placement.resultTitle").replacingOccurrences(of: "{0}", with: recommended ?? level))
                .font(DS.display(30))
                .foregroundColor(DS.ink)
                .padding(.top, 28)
            Text(preview("placement.resultBody"))
                .font(DS.text(16))
                .foregroundColor(DS.ink.opacity(0.8))
                .padding(.top, 8)
            ScrollView {
                LevelPickerList(text: preview, recommended: recommended, selection: $level).padding(.vertical, 18)
            }
            Button {
                finishLevel()
            } label: {
                Text(preview("placement.startWith").replacingOccurrences(of: "{0}", with: level))
            }
            .buttonStyle(PillButtonStyle())
        }
    }

    private var pickStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(preview("placement.pickTitle"))
                .font(DS.display(30))
                .foregroundColor(DS.ink)
                .padding(.top, 28)
            ScrollView {
                LevelPickerList(text: preview, recommended: nil, selection: $level).padding(.vertical, 18)
            }
            Button {
                finishLevel()
            } label: {
                Text(preview("placement.startWith").replacingOccurrences(of: "{0}", with: level))
            }
            .buttonStyle(PillButtonStyle())
            Button {
                step = .test
            } label: {
                Text(preview("placement.wayTest")).frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle())
            .padding(.top, 8)
        }
    }

    /// The chosen level drives the daily text and the practice shown on Today.
    private func finishLevel() {
        if daily.isAvailable(level) { daily.level = level }
        levels.active = level
        step = .reminder
    }

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(preview("onboarding.reminderTitle"))
                .font(DS.display(30))
                .foregroundColor(DS.ink)
                .padding(.top, 28)
            Text(preview("onboarding.reminderText"))
                .font(DS.text(16))
                .foregroundColor(DS.ink.opacity(0.8))
                .padding(.top, 8)
            DatePicker(preview("settings.time"), selection: $reminderTime, displayedComponents: .hourAndMinute)
                .font(DS.text(16))
                .padding(16)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 24)
            Spacer()
            Button {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                daily.reminderMinutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
                Reminders.requestPermission { granted in
                    daily.remindersOn = granted
                    Localizer.shared.choose(language)
                }
            } label: {
                Text(preview("onboarding.allow"))
            }
            .buttonStyle(PillButtonStyle())
            Button {
                Localizer.shared.choose(language)
            } label: {
                Text(preview("onboarding.skip")).frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle())
            .padding(.top, 8)
        }
    }
}
