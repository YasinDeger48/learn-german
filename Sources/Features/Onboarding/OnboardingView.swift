import SwiftUI

/// First launch: Lina greets, asks for the learner's language, then offers the daily reminder.
struct OnboardingView: View {
    @EnvironmentObject private var daily: DailyModel
    @State private var language: AppLanguage = AppLanguage.device
    @State private var step = 0
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

            if step == 0 { languageStep } else { reminderStep }
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
            VStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { lang in
                    let active = lang == language
                    Button {
                        language = lang
                    } label: {
                        HStack(spacing: 14) {
                            Text(lang.code)
                                .font(DS.text(13, .semibold))
                                .foregroundColor(active ? DS.gold : DS.muted)
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
                        .frame(minHeight: 54)
                        .background(active ? DS.night : DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(active ? Color.clear : DS.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(.top, 22)
            Spacer()
            Text(preview("onboarding.changeLater"))
                .font(DS.text(12))
                .foregroundColor(DS.muted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
            Button {
                step = 1
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
