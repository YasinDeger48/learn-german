import SwiftUI

/// The owner's thanks on the About page, as film credits: a cinema screen between velvet curtains, the text rolls
/// up the screen slightly tilted back and fades out at the top, then starts again. Design:
/// https://claude.ai/artifact/CwFN8YLqNLDdk9Li9QErDQ. With Reduce Motion the text stands still.
/// The screen is dark in both light and dark mode, so its colours are fixed.
struct ThanksCinemaView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var creditsHeight: CGFloat = 420

    private static let screenHeight: CGFloat = 232
    private static let rollSeconds: Double = 20
    private static let cream = Color(red: 0.937, green: 0.910, blue: 0.839)
    private static let creamMuted = Color(red: 0.812, green: 0.784, blue: 0.714)
    private static let velvet = [Color(red: 0.290, green: 0.059, blue: 0.082), Color(red: 0.478, green: 0.106, blue: 0.141),
                                 Color(red: 0.369, green: 0.078, blue: 0.106)]
    private static let brass = Color(red: 0.788, green: 0.604, blue: 0.118)

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.043, green: 0.043, blue: 0.035)
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                screen.padding(.horizontal, 52)
                ProjectorBeam()
                    .fill(LinearGradient(colors: [DS.gold.opacity(0), DS.gold.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 260, height: 26)
                Spacer(minLength: 0)
                seats.padding(.horizontal, 44).padding(.bottom, 12)
            }
            HStack(spacing: 0) {
                curtain(widths: [4, 7, 4], shade: .trailing)
                Spacer(minLength: 0)
                curtain(widths: [4, 7, 4], shade: .leading)
            }
            valance
        }
        .frame(height: 336)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.28), radius: 17, y: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("thanks.a11y"))
    }

    // MARK: Screen and rolling credits

    private var screen: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(RadialGradient(colors: [Color(red: 0.169, green: 0.153, blue: 0.090), Color(red: 0.090, green: 0.086, blue: 0.063),
                                              Color(red: 0.059, green: 0.059, blue: 0.047)],
                                     center: .bottom, startRadius: 0, endRadius: 250))
                .shadow(color: DS.gold.opacity(0.16), radius: 23)
            rolling
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.85), lineWidth: 10)
                .blur(radius: 9)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
        }
        .frame(height: Self.screenHeight)
    }

    private var rolling: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let travel = Self.screenHeight + creditsHeight
            let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.rollSeconds) / Self.rollSeconds
            credits
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { proxy in Color.clear.preference(key: CreditsHeightKey.self, value: proxy.size.height) })
                .offset(y: reduceMotion ? 8 : Self.screenHeight - CGFloat(phase) * travel)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.screenHeight, alignment: .top)
        .clipped()
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.26),
                                     .init(color: .black, location: 0.70), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .rotation3DEffect(.degrees(16), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.6)
        .onPreferenceChange(CreditsHeightKey.self) { creditsHeight = max(1, $0) }
    }

    private var credits: some View {
        VStack(spacing: 0) {
            label("DESCHLY", tracking: 3.2)
            Text(t("thanks.title"))
                .font(.system(size: 31, weight: .heavy))
                .foregroundColor(Self.cream)
                .padding(.top, 8)
            Capsule().fill(DS.gold).frame(width: 30, height: 2).padding(.vertical, 12)
            Text(t("thanks.lead")).font(.system(size: 13)).foregroundColor(Self.creamMuted)

            label(t("thanks.wife"), tracking: 2.8).padding(.top, 30)
            name("Emel Değer").padding(.top, 6)

            label(t("thanks.children"), tracking: 2.8).padding(.top, 26)
            name("Zeynep Değer").padding(.top, 6)
            name("Fatih Değer").padding(.top, 4)

            Image(systemName: "heart")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(DS.gold)
                .padding(.top, 30)
            Text(t("thanks.message"))
                .font(.system(size: 14))
                .foregroundColor(Self.cream)
                .lineSpacing(3)
                .frame(maxWidth: 220)
                .padding(.top, 12)

            Text("DEUTSCH LERNEN, LEICHT GEMACHT.")
                .font(.system(size: 10))
                .tracking(2.4)
                .foregroundColor(Color(red: 0.557, green: 0.533, blue: 0.467))
                .padding(.top, 34)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    private func label(_ text: String, tracking: CGFloat) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(tracking).foregroundColor(DS.gold)
    }

    private func name(_ text: String) -> some View {
        Text(text).font(.system(size: 22, weight: .bold)).foregroundColor(Self.cream)
    }

    // MARK: The room

    private var seats: some View {
        HStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { index in
                if index > 0 { Spacer(minLength: 0) }
                UnevenSeat()
                    .fill(LinearGradient(colors: [Color(red: 0.165, green: 0.157, blue: 0.137), Color(red: 0.086, green: 0.082, blue: 0.071)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 28, height: 22)
            }
        }
    }

    private var valance: some View {
        ZStack(alignment: .bottom) {
            Stripes(widths: [10, 8, 4], colors: [Self.velvet[2], Self.velvet[1], Self.velvet[0]])
            Self.brass.frame(height: 2)
        }
        .frame(height: 26)
        .shadow(color: Color.black.opacity(0.6), radius: 5, y: 4)
    }

    private func curtain(widths: [CGFloat], shade: UnitPoint) -> some View {
        Stripes(widths: widths, colors: Self.velvet)
            // The fold darkens towards the screen side (`shade`).
            .overlay(LinearGradient(stops: [.init(color: Color.black.opacity(0), location: 0.4),
                                            .init(color: Color.black.opacity(0.55), location: 1)],
                                    startPoint: shade == .trailing ? .leading : .trailing, endPoint: shade))
            .frame(width: 40)
    }
}

private struct CreditsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 420
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Vertical velvet folds: bands of the given widths and colours, repeated across.
private struct Stripes: View {
    let widths: [CGFloat]
    let colors: [Color]

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            var index = 0
            while x < size.width {
                let width = widths[index % widths.count]
                context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(colors[index % colors.count]))
                x += width
                index += 1
            }
        }
    }
}

/// Light from the projector: narrow at the audience, wide at the screen.
private struct ProjectorBeam: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.54, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.46, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A cinema seat back: round on top, nearly square at the bottom.
private struct UnevenSeat: Shape {
    func path(in rect: CGRect) -> Path {
        let top: CGFloat = 9
        let bottom: CGFloat = 3
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + top), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - bottom, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottom), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
