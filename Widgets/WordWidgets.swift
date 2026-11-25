import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// Four Home Screen word widgets (styles A–D from the mockup) and the Lock Screen widget.

struct WordEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord
    let line: LinaLine
    let level: String
    let turkish: Bool
}

struct WordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), word: WordBank.sample, line: WordBank.sampleLine, level: "A1", turkish: WordBank.turkish)
    }

    func snapshot(for configuration: WordConfigIntent, in context: Context) async -> WordEntry {
        entry(at: Date(), configuration)
    }

    func timeline(for configuration: WordConfigIntent, in context: Context) async -> Timeline<WordEntry> {
        let calendar = Calendar.current
        let now = Date()
        var dates: [Date] = [now]
        if configuration.rotation == .hourly {
            let start = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            dates += (1...24).compactMap { calendar.date(byAdding: .hour, value: $0, to: start) }
        } else {
            let start = calendar.startOfDay(for: now)
            dates += (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }
        return Timeline(entries: dates.map { entry(at: $0, configuration) }, policy: .atEnd)
    }

    private func entry(at date: Date, _ configuration: WordConfigIntent) -> WordEntry {
        let period = configuration.rotation == .hourly
            ? Int(date.timeIntervalSince1970 / 3600)
            : Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400)
        let index = period + UserDefaults.standard.integer(forKey: "skip")
        let level = configuration.level.rawValue
        return WordEntry(date: date, word: WordBank.word(level: level, index: index), line: WordBank.line(index: index),
                         level: level, turkish: WordBank.turkish)
    }
}

// MARK: - A · Night

struct NightView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        let w = entry.word
        let glow = RadialGradient(colors: [Palette.article(w.a).opacity(0.55), .clear],
                                  center: .topTrailing, startRadius: 2, endRadius: family == .systemMedium ? 200 : 130)
        Group {
            if family == .systemMedium {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        tag(w)
                        Spacer(minLength: 0)
                        Text(w.d).font(.system(size: 24, weight: .heavy)).foregroundColor(Palette.cream)
                            .lineLimit(2).minimumScaleFactor(0.6)
                        Text(w.meaning(entry.turkish)).font(.system(size: 13)).foregroundColor(Palette.cream.opacity(0.7)).lineLimit(2)
                        Spacer(minLength: 0)
                        Text("deschly. \(entry.level)").font(.system(size: 10, weight: .heavy)).foregroundColor(Palette.cream.opacity(0.5))
                    }
                    .frame(width: 128, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("„\(w.x)“").font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.cream)
                            .lineLimit(4).minimumScaleFactor(0.8)
                        Text(w.exampleMeaning(entry.turkish)).font(.system(size: 12)).foregroundColor(Palette.cream.opacity(0.6)).lineLimit(3)
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            Spacer()
                            WidgetIconButton(intent: NextWordIntent(), symbol: "arrow.forward", foreground: Palette.night,
                                             background: Palette.gold, label: WidgetText.next(entry.turkish))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        tag(w)
                        Spacer()
                        Text(entry.level).font(.system(size: 10, weight: .heavy)).foregroundColor(Palette.cream.opacity(0.5))
                    }
                    Spacer(minLength: 0)
                    Text(w.d).font(.system(size: 23, weight: .heavy)).foregroundColor(Palette.cream).lineLimit(2).minimumScaleFactor(0.55)
                    Text(w.meaning(entry.turkish)).font(.system(size: 13)).foregroundColor(Palette.cream.opacity(0.7)).lineLimit(2)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        WidgetIconButton(intent: NextWordIntent(), symbol: "arrow.forward", foreground: Palette.night,
                                         background: Palette.gold, label: WidgetText.next(entry.turkish))
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.106, green: 0.11, blue: 0.133), Palette.night], startPoint: .top, endPoint: .bottom)
                glow
            }
        }
    }

    private func tag(_ w: WidgetWord) -> some View {
        Text(w.a.isEmpty ? entry.level : w.a)
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Palette.article(w.a), in: Capsule())
    }
}

// MARK: - B · Paper

struct PaperView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        let w = entry.word
        let accent = Palette.article(w.a)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.turkish ? "GÜNÜN KELİMESİ" : "WORD OF THE DAY")
                    .font(.system(size: 10, weight: .heavy)).foregroundColor(Color(red: 0.6, green: 0.44, blue: 0))
                if family == .systemMedium { Text("· \(entry.level)").font(.system(size: 10, weight: .heavy)).foregroundColor(Palette.muted) }
                Spacer()
                if family == .systemMedium {
                    (Text("deschly").foregroundColor(Palette.night) + Text(".").foregroundColor(Palette.gold))
                        .font(.system(size: 11, weight: .heavy))
                }
            }
            Spacer(minLength: 0)
            if !w.a.isEmpty { Text(w.a).font(.system(size: 13, weight: .bold)).foregroundColor(accent) }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(w.d)
                    .font(.system(size: family == .systemMedium ? 28 : 26, weight: .bold, design: .serif))
                    .foregroundColor(Palette.night)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.bottom, 3)
                    .overlay(alignment: .bottom) { Rectangle().fill(accent).frame(height: 3) }
                if family == .systemMedium {
                    Text(w.meaning(entry.turkish)).font(.system(size: 14)).foregroundColor(Palette.muted).lineLimit(1)
                }
            }
            if family != .systemMedium {
                Text(w.meaning(entry.turkish)).font(.system(size: 13)).foregroundColor(Palette.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                if family == .systemMedium {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("„\(w.x)“").font(.system(size: 14, design: .serif)).italic().foregroundColor(Palette.night).lineLimit(2)
                        Text(w.exampleMeaning(entry.turkish)).font(.system(size: 11)).foregroundColor(Palette.muted).lineLimit(1)
                    }
                } else {
                    Text(entry.level).font(.system(size: 11, weight: .bold)).foregroundColor(Palette.muted)
                }
                Spacer(minLength: 6)
                WidgetIconButton(intent: NextWordIntent(), symbol: "arrow.forward", foreground: Palette.gold,
                                 background: Palette.night, label: WidgetText.next(entry.turkish))
            }
        }
        .containerBackground(for: .widget) { Palette.paper }
    }
}

// MARK: - C · Article colour

struct ColorView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        let w = entry.word
        let watermark = w.a.isEmpty ? entry.level : w.a
        Group {
            if family == .systemMedium {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(watermark).font(.system(size: 12, weight: .heavy)).foregroundColor(.white.opacity(0.85))
                        Spacer(minLength: 0)
                        Text(w.d).font(.system(size: 26, weight: .black)).foregroundColor(.white).lineLimit(2).minimumScaleFactor(0.55)
                        Text(w.meaning(entry.turkish)).font(.system(size: 14)).foregroundColor(.white.opacity(0.85)).lineLimit(2)
                    }
                    .frame(width: 126, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("„\(w.x)“").font(.system(size: 13, weight: .bold)).foregroundColor(.white).lineLimit(3).minimumScaleFactor(0.8)
                            Text(w.exampleMeaning(entry.turkish)).font(.system(size: 11)).foregroundColor(.white.opacity(0.8)).lineLimit(2)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            Spacer()
                            WidgetIconButton(intent: NextWordIntent(), symbol: "arrow.forward", foreground: Palette.article(w.a),
                                             background: .white, label: WidgetText.next(entry.turkish))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(watermark).font(.system(size: 12, weight: .heavy)).foregroundColor(.white.opacity(0.85))
                    Spacer(minLength: 0)
                    Text(w.d).font(.system(size: 24, weight: .black)).foregroundColor(.white).lineLimit(2).minimumScaleFactor(0.5)
                    Text(w.meaning(entry.turkish)).font(.system(size: 13)).foregroundColor(.white.opacity(0.85)).lineLimit(2)
                    Spacer(minLength: 0)
                    HStack {
                        Text(entry.level).font(.system(size: 10, weight: .heavy)).foregroundColor(.white.opacity(0.7))
                        Spacer()
                        WidgetIconButton(intent: NextWordIntent(), symbol: "arrow.forward", foreground: Palette.article(w.a),
                                         background: .white, label: WidgetText.next(entry.turkish))
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            ZStack(alignment: .bottomTrailing) {
                Palette.articleGradient(w.a)
                Text(watermark)
                    .font(.system(size: family == .systemMedium ? 130 : 110, weight: .black))
                    .foregroundColor(.white.opacity(0.11))
                    .offset(x: 12, y: 36)
            }
        }
    }
}

// MARK: - D · Lina

struct LinaView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    private var lina: some View {
        Group {
            if let image = UIImage(named: "lina") {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Palette.gold
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Palette.gold, lineWidth: 3))
    }

    var body: some View {
        let line = entry.line
        let meaning = entry.turkish ? line.tr : line.en
        Group {
            if family == .systemMedium {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(spacing: 4) {
                        lina.frame(width: 80, height: 80)
                        Text("deschly. \(line.l)").font(.system(size: 10, weight: .heavy)).foregroundColor(Palette.muted)
                    }
                    VStack(alignment: .trailing, spacing: 8) {
                        bubble(line.s, meaning, big: true)
                        HStack(spacing: 8) {
                            WidgetIconButton(intent: NextWordIntent(), symbol: "arrow.forward", foreground: Palette.night,
                                             background: Palette.gold, label: WidgetText.next(entry.turkish))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    bubble(line.s, meaning, big: false)
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom) {
                        lina.frame(width: 54, height: 54)
                        Spacer()
                        WidgetIconButton(intent: NextWordIntent(), symbol: "arrow.forward", foreground: Palette.night,
                                         background: Palette.gold, label: WidgetText.next(entry.turkish))
                    }
                }
            }
        }
        .containerBackground(for: .widget) { Color.white }
    }

    private func bubble(_ german: String, _ meaning: String, big: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if big {
                Text(entry.turkish ? "Lina diyor ki:" : "Lina says:").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.6))
            }
            Text(german).font(.system(size: big ? 18 : 15, weight: .heavy)).foregroundColor(.white).lineLimit(3).minimumScaleFactor(0.7)
            Text(meaning).font(.system(size: big ? 13 : 12)).foregroundColor(Palette.gold).lineLimit(2)
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.night, in: UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 4,
                                                             bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous))
    }
}

// MARK: - Lock Screen

struct LockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        let w = entry.word
        Group {
            switch family {
            case .accessoryInline:
                Text("\(w.full) · \(w.meaning(entry.turkish))")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Text(w.a.isEmpty ? entry.level : w.a).font(.system(size: 11, weight: .heavy))
                        Text(w.d).font(.system(size: 13, weight: .bold)).lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .padding(4)
                }
                .widgetAccentable()
            default:
                VStack(alignment: .leading, spacing: 1) {
                    Text(w.full).font(.headline).lineLimit(1).minimumScaleFactor(0.7).widgetAccentable()
                    Text(w.meaning(entry.turkish)).font(.caption).lineLimit(1)
                    Text(w.x).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

// MARK: - Widgets

private func describe(_ tr: String, _ en: String) -> String { WordBank.turkish ? tr : en }

struct NightWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DeschlyNight", intent: WordConfigIntent.self, provider: WordProvider()) { NightView(entry: $0) }
            .configurationDisplayName(describe("Kelime · Gece", "Word · Night"))
            .description(describe("Koyu zemin, artikel renginde ışık, örnek cümle.", "Dark card with an article-coloured glow and an example."))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PaperWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DeschlyPaper", intent: WordConfigIntent.self, provider: WordProvider()) { PaperView(entry: $0) }
            .configurationDisplayName(describe("Günün kelimesi · Kâğıt", "Word of the day · Paper"))
            .description(describe("Açık kâğıt zemin, dergi gibi büyük kelime.", "Light paper card with an editorial word."))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ColorWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DeschlyWord", intent: WordConfigIntent.self, provider: WordProvider()) { ColorView(entry: $0) }
            .configurationDisplayName(describe("Kelime · Artikel rengi", "Word · Article colour"))
            .description(describe("der mavi, die kırmızı, das yeşil: renk artikeli söyler.", "Blue der, red die, green das: the colour tells the article."))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LinaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DeschlyLina", intent: WordConfigIntent.self, provider: WordProvider()) { LinaView(entry: $0) }
            .configurationDisplayName(describe("Lina diyor ki", "Lina says"))
            .description(describe("Lina\u{2019}dan günlük hayattan kısa bir cümle.", "A short everyday sentence from Lina."))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DeschlyLock", intent: WordConfigIntent.self, provider: WordProvider()) { LockView(entry: $0) }
            .configurationDisplayName(describe("Kilit ekranı kelimesi", "Lock Screen word"))
            .description(describe("Kilit ekranında anlamıyla bir Almanca kelime.", "A German word with its meaning on the Lock Screen."))
            .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct DeschlyWidgets: WidgetBundle {
    var body: some Widget {
        ColorWidget()
        QuizWidget()
        NightWidget()
        PaperWidget()
        LinaWidget()
        LockWidget()
    }
}
