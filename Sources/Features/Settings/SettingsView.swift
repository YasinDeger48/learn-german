import SwiftUI

/// Language, daily reminder, and one row for backup and app info.
struct SettingsView: View {
    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var localizer: Localizer
    @State private var permissionDenied = false
    @State private var showPlacement = false
    @AppStorage(Reminders.wordsKey) private var notifyWords = true
    @AppStorage(Reminders.streakKey) private var notifyStreak = true

    private var reminderTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(hour: daily.reminderMinutes / 60, minute: daily.reminderMinutes % 60)) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            daily.reminderMinutes = (parts.hour ?? 8) * 60 + (parts.minute ?? 0)
        })
    }

    private var remindersBinding: Binding<Bool> {
        Binding(get: { daily.remindersOn }, set: { on in
            if on {
                Reminders.requestPermission { granted in
                    daily.remindersOn = granted
                    permissionDenied = !granted
                }
            } else {
                daily.remindersOn = false
            }
        })
    }

    var body: some View {
        Form {
                ProSettingsSection()
                Section(t("settings.language")) {
                    Picker(t("settings.language"), selection: Binding(get: { localizer.language }, set: { localizer.choose($0) })) {
                        ForEach(AppLanguage.offered) { lang in
                            HStack(spacing: 10) {
                                LanguageFlag(language: lang, size: 18)
                                Text(lang.nativeName)
                            }
                            .tag(lang)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section {
                    Toggle(t("settings.remind"), isOn: remindersBinding)
                    if daily.remindersOn {
                        DatePicker(t("settings.time"), selection: reminderTime, displayedComponents: .hourAndMinute)
                        Toggle(t("settings.notifyWords"), isOn: $notifyWords)
                            .onChange(of: notifyWords) { _ in Reminders.refresh(daily) }
                        Toggle(t("settings.notifyStreak"), isOn: $notifyStreak)
                            .onChange(of: notifyStreak) { _ in Reminders.refresh(daily) }
                    }
                    Picker(t("settings.myLevel"), selection: $daily.level) {
                        ForEach(DailyModel.levels.filter { daily.isAvailable($0) }, id: \.self) { Text($0).tag($0) }
                    }
                    Button(t("placement.retake")) { showPlacement = true }
                } header: {
                    Text(t("settings.daily"))
                } footer: {
                    Text(permissionDenied ? t("settings.permissionDenied") : t("settings.dailyFooter"))
                }
                Section {
                    NavigationLink {
                        AboutAppView()
                    } label: {
                        HStack {
                            Label(t("settings.appInfo"), systemImage: "info.circle")
                            Spacer()
                            Text(AboutAppView.version).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(t("settings.appInfoFooter"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.ground.ignoresSafeArea())
            .navigationTitle(t("settings.title"))
            .sheet(isPresented: $showPlacement) { PlacementSheet() }
        .tint(DS.accent)
    }
}

/// About the app: backup, privacy, version and credits on one page.
struct AboutAppView: View {
    @State private var exporting = false
    @State private var importing = false
    @State private var document: BackupDocument?
    @State private var status: String?
    @ObservedObject private var ads = AdsManager.shared

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section {
                Button {
                    document = BackupService.make()
                    exporting = document != nil
                } label: {
                    Label(t("settings.backupSave"), systemImage: "square.and.arrow.up")
                }
                Button { importing = true } label: {
                    Label(t("settings.backupRestore"), systemImage: "square.and.arrow.down")
                }
                if let status { Text(status).font(.footnote).foregroundStyle(.secondary) }
            } header: {
                Text(t("settings.backup"))
            } footer: {
                Text(t("settings.backupFooter"))
            }
            Section(t("settings.about")) {
                Link(destination: LegalLinks.privacy) {
                    Label(t("settings.privacy"), systemImage: "hand.raised")
                }
                if ads.privacyOptionsRequired {
                    Button { ads.showPrivacyOptions() } label: {
                        Label(t("settings.adPrivacy"), systemImage: "megaphone")
                    }
                }
                HStack {
                    Label(t("settings.version"), systemImage: "number")
                    Spacer()
                    Text(Self.version).foregroundStyle(.secondary)
                }
            }
            Section {
                Text(t("settings.credits")).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("settings.appInfo"))
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Deschly-Backup") { result in
            if case .success = result { status = t("backup.saved") } else { status = t("backup.saveFailed") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { status = t(BackupService.restore(from: url)) }
        }
        .tint(DS.accent)
    }
}
