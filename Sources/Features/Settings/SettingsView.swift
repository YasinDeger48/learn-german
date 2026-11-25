import SwiftUI

/// Language, daily reminder, backup and app info.
struct SettingsView: View {
    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var localizer: Localizer
    @State private var exporting = false
    @State private var importing = false
    @State private var document: BackupDocument?
    @State private var status: String?
    @State private var permissionDenied = false
    @ObservedObject private var ads = AdsManager.shared
    @State private var showPlacement = false

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
                        ForEach(AppLanguage.offered) { Text($0.nativeName).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section {
                    Toggle(t("settings.remind"), isOn: remindersBinding)
                    if daily.remindersOn {
                        DatePicker(t("settings.time"), selection: reminderTime, displayedComponents: .hourAndMinute)
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
                    Button(t("settings.backupSave")) {
                        document = BackupService.make()
                        exporting = document != nil
                    }
                    Button(t("settings.backupRestore")) { importing = true }
                    if let status { Text(status).font(.footnote).foregroundStyle(.secondary) }
                } header: {
                    Text(t("settings.backup"))
                } footer: {
                    Text(t("settings.backupFooter"))
                }
                Section(t("settings.about")) {
                    Link(t("settings.privacy"), destination: LegalLinks.privacy)
                    if ads.privacyOptionsRequired {
                        Button(t("settings.adPrivacy")) { ads.showPrivacyOptions() }
                    }
                    HStack {
                        Text(t("settings.version"))
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    Text(t("settings.credits")).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.ground.ignoresSafeArea())
            .navigationTitle(t("settings.title"))
            .sheet(isPresented: $showPlacement) { PlacementSheet() }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Deschly-Backup") { result in
                if case .success = result { status = t("backup.saved") } else { status = t("backup.saveFailed") }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { status = t(BackupService.restore(from: url)) }
            }
        .tint(DS.accent)
    }
}
