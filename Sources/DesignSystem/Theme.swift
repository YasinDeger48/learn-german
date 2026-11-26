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

    // Native iOS colours: grouped backgrounds, labels and separators follow light/dark mode automatically.
    static let ground = Color(UIColor.systemGroupedBackground)
    static let surface = Color(UIColor.secondarySystemGroupedBackground)
    static let ink = Color(UIColor.label)
    static let muted = Color(UIColor.secondaryLabel)
    static let hairline = Color(UIColor.separator)
    /// Dark feature cards (daily text, feedback sheet). Slightly lifted in dark mode.
    static let night = dynamic(0x0E0F0C, 0x23251F)
    static let onNight = Color(red: 0.969, green: 0.969, blue: 0.957)
    static let onNightMuted = Color(red: 0.663, green: 0.671, blue: 0.639)
    /// Tint for links, toggles and system buttons.
    static let accent = dynamic(0x2F5BEA, 0x8FA9FF)
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

    /// System font (SF Pro), like Apple's own apps. Sizes scale with Dynamic Type through `relativeTo`.
    static func display(_ size: CGFloat, heavy: Bool = true) -> Font {
        .system(size: scaled(size, max: 1.25), weight: heavy ? .bold : .semibold, design: .default)
    }

    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size, max: 1.4), weight: weight)
    }

    /// Follows the iPhone's text size (Settings → Display → Text Size), within limits so cards keep their shape.
    static func scaled(_ size: CGFloat, max factor: CGFloat) -> CGFloat {
        let value = UIFontMetrics.default.scaledValue(for: size)
        return min(Swift.max(value, size * 0.85), size * factor)
    }

    /// Bundled brand face, used only for the "deschly." wordmark.
    static func brand(_ size: CGFloat) -> Font {
        .custom("DeschlyDisplay-ExtraBold", size: size)
    }

    static let radius: CGFloat = 22
    static let gutter: CGFloat = 16
}

// MARK: - Components

/// Lina, the Deschly mascot (Resources/Images/lina.png).
/// How Lina looks: the usual picture, one of her happy / sad pictures after an answer,
/// or curious (the "Curious about German" badge).
enum LinaMood { case calm, happy, sad, curious }

struct LinaAvatar: View {
    var size: CGFloat = 56
    var mood: LinaMood = .calm
    /// Chooses among the mood's pictures; the same number always gives the same picture.
    var variant: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Animation state: happy = a small hop, sad = head tilts down, curious = gentle sway.
    @State private var moved = false
    @State private var blinking = false
    private let blinkClock = Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()

    /// Resources/Images/lina-happy-1…3.png, lina-sad-1…3.png and lina-curious.png (made with ChatGPT, see
    /// icerik/gorseller/LINA_DUYGULAR.txt). Missing pictures fall back to the usual Lina.
    private var pictureName: String {
        switch mood {
        case .calm:
            // The old lina.png has a big "D" behind her: prefer the waving picture without it.
            return LinaAvatar.calmName
        case .curious:
            return UIImage(named: "lina-curious") != nil ? "lina-curious" : "lina"
        case .happy, .sad:
            let base = mood == .happy ? "lina-happy" : "lina-sad"
            let names = (1...3).map { "\(base)-\($0)" }.filter { UIImage(named: $0) != nil }
            return names.isEmpty ? "lina" : names[abs(variant) % names.count]
        }
    }

    /// The same picture with closed eyes ("<name>-blink.png"), if there is one: used for blinking.
    private var blinkPicture: UIImage? {
        let name = pictureName + "-blink"
        if let known = LinaAvatar.hasBlink[name], !known { return nil }
        let image = UIImage(named: name)
        LinaAvatar.hasBlink[name] = image != nil
        return image
    }
    /// The calm Lina: lina-wave.png (no "D" behind her), else a happy one, else the old lina.png.
    static let calmName: String = ["lina-wave", "lina-happy-1", "lina"].first { UIImage(named: $0) != nil } ?? "lina"
    /// Which closed-eye pictures exist (asked once per name).
    private static var hasBlink: [String: Bool] = [:]

    private var picture: UIImage? {
        if blinking, let closed = blinkPicture { return closed }
        return UIImage(named: pictureName)
    }

    private var lift: CGFloat {
        guard moved else { return 0 }
        switch mood {
        case .happy: return -size * 0.06
        case .sad: return size * 0.03
        default: return 0
        }
    }

    private var tilt: Double {
        guard moved else { return mood == .curious ? -2.5 : 0 }
        switch mood {
        case .happy: return 4
        case .sad: return -5
        case .curious: return 2.5
        case .calm: return 0
        }
    }

    var body: some View {
        Group {
            if let image = picture {
                // A little larger than the tile, so moving never shows an empty edge.
                Image(uiImage: image).resizable().scaledToFill()
                    .scaleEffect(mood == .calm ? 1 : 1.1)
                    .rotationEffect(.degrees(tilt), anchor: .bottom)
                    .offset(y: lift)
            } else {
                DS.gold
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        .accessibilityLabel("Lina")
        .onAppear { animate() }
        .onReceive(blinkClock) { _ in blink() }
    }

    private func animate() {
        guard !reduceMotion else { return }
        moved = false
        switch mood {
        case .happy:
            withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { moved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { moved = false }
            }
        case .sad:
            withAnimation(.easeInOut(duration: 0.7).delay(0.1)) { moved = true }
        case .curious:
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { moved = true }
        case .calm:
            break
        }
    }

    private func blink() {
        guard !reduceMotion, blinkPicture != nil, !blinking else { return }
        blinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { blinking = false }
    }
}

/// Cover illustration of a daily text (Resources/Covers/<id>.jpg). Nothing is shown when a text has no cover yet.
enum Covers {
    /// Decoded pictures, kept while memory allows (the system empties it when memory is low).
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        cache.totalCostLimit = 120 * 1024 * 1024
        return cache
    }()
    /// Ids without a picture, so the files are not looked for again on every render.
    private static var missing = Set<String>()
    private static let lock = NSLock()

    /// Whether a picture exists, without decoding it (for choosing many words at once).
    static func exists(_ id: String) -> Bool {
        ContentStore.cached("covers/\(id).jpg") != nil || Bundle.main.path(forResource: id, ofType: "jpg") != nil
    }

    static func image(_ id: String) -> UIImage? {
        lock.lock()
        let known = cache.object(forKey: id as NSString)
        let none = missing.contains(id)
        lock.unlock()
        if let known { return known }
        if none { return nil }
        let path = ContentStore.cached("covers/\(id).jpg")?.path ?? Bundle.main.path(forResource: id, ofType: "jpg")
        guard let path, let file = UIImage(contentsOfFile: path) else {
            lock.lock(); missing.insert(id); lock.unlock()
            return nil
        }
        // Decode now, once, instead of at every draw.
        let image = file.preparingForDisplay() ?? file
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        lock.lock(); cache.setObject(image, forKey: id as NSString, cost: cost); lock.unlock()
        return image
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
            .font(DS.brand(size))
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
var a1Accent: Color { DS.accent }

/// Native press feedback for cards and rows drawn as buttons: a slight shrink and dim while touched,
/// like system lists and App Store cards.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
