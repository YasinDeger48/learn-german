import SwiftUI
import UIKit

/// Deschly design tokens. Mirrors the mockup: ink, gold, warm white, article colours.
/// Keep these values in sync with docs/ARCHITECTURE.md so web and Android can reuse them.
enum DS {
    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    static let ground = dynamic(0xF7F7F4, 0x0E0F0C)
    static let surface = dynamic(0xFFFFFF, 0x1A1B17)
    static let ink = dynamic(0x0E0F0C, 0xF2F2EE)
    static let muted = dynamic(0x5E615A, 0xA9ABA3)
    static let hairline = dynamic(0xE6E6E0, 0x2A2C27)
    /// Dark feature cards (daily text, feedback sheet). Slightly lifted in dark mode.
    static let night = dynamic(0x0E0F0C, 0x23251F)
    static let onNight = Color(red: 0.969, green: 0.969, blue: 0.957)
    static let onNightMuted = Color(red: 0.663, green: 0.671, blue: 0.639)
    static let gold = Color(red: 0.949, green: 0.761, blue: 0.188)
    static let goldDeep = dynamic(0x9A6F00, 0xF2C230)
    static let onGold = Color(red: 0.055, green: 0.059, blue: 0.047)
    static let der = dynamic(0x2F5BEA, 0x8FA9FF)
    static let die = dynamic(0xC8323A, 0xFF8A8E)
    static let das = dynamic(0x157A41, 0x5FD08A)
    static let success = dynamic(0x157A41, 0x5FD08A)
    static let successSoft = dynamic(0xE5F3EA, 0x17301F)
    static let error = dynamic(0xC8323A, 0xFF8A8E)
    static let errorSoft = dynamic(0xFBEAEA, 0x3A1C1D)
    static let chip = dynamic(0xEEEEE9, 0x23251F)

    // Fonts are bundled in Resources/Fonts (OFL): DeschlyDisplay = Bricolage Grotesque, DeschlyText = Geist.
    static func display(_ size: CGFloat, heavy: Bool = true) -> Font {
        .custom(heavy ? "DeschlyDisplay-ExtraBold" : "DeschlyDisplay-Bold", size: size, relativeTo: .title)
    }

    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy, .black: name = "DeschlyText-SemiBold"
        case .medium: name = "DeschlyText-Medium"
        default: name = "DeschlyText-Regular"
        }
        return .custom(name, size: size, relativeTo: size >= 20 ? .title3 : (size >= 16 ? .body : .footnote))
    }

    static let radius: CGFloat = 22
    static let gutter: CGFloat = 22
}

// MARK: - Components

/// Lina, the Deschly mascot (Resources/Images/lina.png).
struct LinaAvatar: View {
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let image = UIImage(named: "lina") {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                DS.gold
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        .accessibilityLabel("Lina")
    }
}

/// Cover illustration of a daily text (Resources/Covers/<id>.jpg). Nothing is shown when a text has no cover yet.
enum Covers {
    static func image(_ id: String) -> UIImage? {
        guard let path = Bundle.main.path(forResource: id, ofType: "jpg") else { return nil }
        return UIImage(contentsOfFile: path)
    }
}

struct CoverImage: View {
    let image: UIImage
    var height: CGFloat = 200
    var radius: CGFloat = DS.radius

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// "deschly." wordmark.
struct Wordmark: View {
    var size: CGFloat = 22

    var body: some View {
        (Text("deschly").foregroundColor(DS.ink) + Text(".").foregroundColor(DS.goldDeep))
            .font(DS.display(size))
            .tracking(-0.8)
            .accessibilityLabel("Deschly")
    }
}

/// Big pill button: gold by default, ink for secondary emphasis.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = DS.gold
    var foreground: Color = DS.onGold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.text(16, .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined pill for quieter actions.
struct GhostButtonStyle: ButtonStyle {
    var foreground: Color = DS.ink
    var border: Color = DS.hairline

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.text(15, .medium))
            .foregroundColor(foreground)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .overlay(Capsule().stroke(border, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Row in a hairline list: icon slot, title, trailing note, chevron.
struct ListRow<Leading: View>: View {
    let title: String
    var note: String? = nil
    var showsDivider = true
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                leading().frame(width: 34, alignment: .leading)
                Text(title).font(DS.text(16, .medium)).foregroundColor(DS.ink)
                Spacer(minLength: 8)
                if let note {
                    Text(note).font(DS.text(13)).foregroundColor(DS.muted).lineLimit(1)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(DS.muted)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            if showsDivider { Rectangle().fill(DS.hairline).frame(height: 1) }
        }
    }
}

/// der / die / das colour triad used as the Artikel icon.
struct ArticleBars: View {
    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3).fill(DS.der).frame(width: 8, height: 22)
            RoundedRectangle(cornerRadius: 3).fill(DS.die).frame(width: 8, height: 22)
            RoundedRectangle(cornerRadius: 3).fill(DS.das).frame(width: 8, height: 22)
        }
        .accessibilityHidden(true)
    }
}

/// Section header in the display face.
struct SectionTitle: View {
    let title: String
    var note: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(DS.display(19, heavy: false)).foregroundColor(DS.ink)
            Spacer()
            if let note { Text(note).font(DS.text(13)).foregroundColor(DS.muted) }
        }
    }
}

/// Round icon button (back, close, settings).
struct CircleIconButton: View {
    let systemName: String
    let label: String
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DS.ink)
                .frame(width: 44, height: 44)
                .background(filled ? DS.surface : Color.clear, in: Circle())
                .overlay(Circle().stroke(DS.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension View {
    /// Standard page background and side gutter.
    func deschlyPage() -> some View {
        self.background(DS.ground.ignoresSafeArea())
    }

    /// White card with a hairline.
    func deschlyCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.radius, style: .continuous).stroke(DS.hairline, lineWidth: 1))
    }
}

/// Shared accent for older practice screens.
var a1Accent: Color { DS.ink }
