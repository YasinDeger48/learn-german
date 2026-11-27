import SwiftUI
import UIKit

/// Light, dark or the iPhone's setting (Settings → Appearance). Set on the windows, so sheets follow too.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "ui.appearance"
    var id: String { rawValue }
    var titleKey: String { "theme.\(rawValue)" }

    static var current: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    private var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Applies the saved choice to every window of the app.
    static func apply() {
        let style = current.style
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}

/// The colours a palette changes. Article (der/die/das) and right/wrong colours stay the same in every palette
/// because they carry meaning.
struct PaletteColors {
    let night: Color
    let gold: Color
    let goldDeep: Color
    let onGold: Color
    let accent: Color
    let chip: Color
}

/// Colour themes (Settings → Appearance). `night` is the dark card colour, `gold` the highlight on buttons, rings and
/// stars, `goldDeep` the highlight as text on light backgrounds. Each value is (light mode, dark mode).
enum AppPalette: String, CaseIterable, Identifiable {
    case classic, mono, ocean, forest, sunset, lavender

    static let storageKey = "ui.palette"
    var id: String { rawValue }
    var titleKey: String { "theme.palette.\(rawValue)" }
    /// Classic and black-and-white are free; the colour palettes come with Pro.
    var needsPro: Bool { self != .classic && self != .mono }

    static private(set) var current: AppPalette =
        AppPalette(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .classic
    static private(set) var colors: PaletteColors = current.make()
    /// Set when the palette changes from Settings: the rebuilt screens open Settings again.
    static var reopenSettings = false

    /// Saves the palette. The app root watches the stored value and rebuilds every screen with the new colours.
    static func choose(_ palette: AppPalette) {
        guard palette != current else { return }
        current = palette
        colors = palette.make()
        reopenSettings = true
        UserDefaults.standard.set(palette.rawValue, forKey: storageKey)
    }

    func make() -> PaletteColors {
        let c = DS.dynamic
        switch self {
        case .classic:
            return PaletteColors(night: c(0x0E0F0C, 0x23251F), gold: c(0xF2C230, 0xF2C230), goldDeep: c(0x9A6F00, 0xF2C230),
                                 onGold: c(0x0E0F0C, 0x0E0F0C), accent: c(0x2F5BEA, 0x8FA9FF), chip: c(0xEEEEE9, 0x23251F))
        case .mono:
            return PaletteColors(night: c(0x111111, 0x262626), gold: c(0xD6D6D6, 0xF0F0F0), goldDeep: c(0x111111, 0xF0F0F0),
                                 onGold: c(0x111111, 0x111111), accent: c(0x111111, 0xF5F5F5), chip: c(0xEFEFEF, 0x262626))
        case .ocean:
            return PaletteColors(night: c(0x0C2235, 0x15304A), gold: c(0x5CCFEF, 0x5CCFEF), goldDeep: c(0x0B6C8A, 0x5CCFEF),
                                 onGold: c(0x06202F, 0x06202F), accent: c(0x1F6FD1, 0x7FB2FF), chip: c(0xE8EFF3, 0x15304A))
        case .forest:
            return PaletteColors(night: c(0x13271D, 0x1F3A2C), gold: c(0xA6E36A, 0xA6E36A), goldDeep: c(0x3E7A14, 0xA6E36A),
                                 onGold: c(0x0F2414, 0x0F2414), accent: c(0x1E7A55, 0x6FD3A6), chip: c(0xEAF0EA, 0x1F3A2C))
        case .sunset:
            return PaletteColors(night: c(0x2B1320, 0x3B1D2D), gold: c(0xFFA36E, 0xFFA36E), goldDeep: c(0xB0501C, 0xFFA36E),
                                 onGold: c(0x2B1320, 0x2B1320), accent: c(0xD2416A, 0xFF8FAB), chip: c(0xF4ECEC, 0x3B1D2D))
        case .lavender:
            return PaletteColors(night: c(0x1E1839, 0x2C2651), gold: c(0xC7B8FF, 0xC7B8FF), goldDeep: c(0x5B45C9, 0xC7B8FF),
                                 onGold: c(0x1E1839, 0x1E1839), accent: c(0x5B45C9, 0xA996FF), chip: c(0xEEEBF6, 0x2C2651))
        }
    }
}

/// Settings section: appearance (system / light / dark) and the colour palettes as swatches.
struct AppearanceSettingsSection: View {
    @EnvironmentObject private var pro: ProStore
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage(AppPalette.storageKey) private var paletteRaw = AppPalette.classic.rawValue
    @State private var showPaywall = false

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        Section {
            Picker(t("theme.appearance"), selection: Binding(get: { AppAppearance(rawValue: appearanceRaw) ?? .system },
                                                             set: { appearanceRaw = $0.rawValue; AppAppearance.apply() })) {
                ForEach(AppAppearance.allCases) { Text(t($0.titleKey)).tag($0) }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AppPalette.allCases) { palette in
                    swatch(palette)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text(t("theme.title"))
        } footer: {
            Text(t("theme.footer"))
        }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(pro) }
    }

    private func swatch(_ palette: AppPalette) -> some View {
        let colors = palette.make()
        let chosen = (AppPalette(rawValue: paletteRaw) ?? .classic) == palette
        let locked = palette.needsPro && !pro.isPro
        return Button {
            if locked { showPaywall = true } else { AppPalette.choose(palette) }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.night)
                    HStack(spacing: 6) {
                        Circle().fill(colors.gold).frame(width: 20, height: 20)
                        Circle().fill(colors.accent).frame(width: 14, height: 14)
                    }
                }
                .frame(height: 48)
                .overlay(alignment: .topTrailing) { if locked { ProChip().scaleEffect(0.8).padding(3) } }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(chosen ? colors.goldDeep : DS.hairline, lineWidth: chosen ? 3 : 1)
                )
                Text(t(palette.titleKey))
                    .font(.caption.weight(chosen ? .bold : .regular))
                    .foregroundColor(DS.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t(palette.titleKey))
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
