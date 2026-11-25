import SwiftUI
import UIKit

/// Wraps word tokens like text, so single words can be tapped.
struct FlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Daily text: listen, tap words for article / meaning, show the translation, then the quiz.
struct DailyReadingView: View {
    @EnvironmentObject private var daily: DailyModel
    let text: DailyText
    @State private var selected: DailyGloss?
    @State private var showTranslation = false
    @State private var playing = false
    @State private var speedIndex = 0
    /// Long-press bubble: token id and what it shows.
    @State private var bubbleID: String?
    @State private var bubble: WordInfo?
    @State private var bubbleWord = ""
    @Environment(\.dismiss) private var dismiss

    private let speeds: [Float] = [1.0, 0.8, 0.6]
    private let speedLabels = ["1×", "0.8×", "0.6×"]

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let cover = Covers.image(text.id) {
                        CoverImage(image: cover, height: 220).padding(.bottom, 16)
                    }
                    Text("\(text.level) · \(text.topic) · \(text.minutes) min")
                        .font(DS.text(13))
                        .foregroundColor(DS.muted)
                    Text(text.title)
                        .font(DS.display(36))
                        .tracking(-1.4)
                        .foregroundColor(DS.ink)
                        .padding(.top, 8)
                    player.padding(.top, 18)
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(text.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            VStack(alignment: .leading, spacing: 8) {
                                FlowLayout {
                                    ForEach(Array(tokens(paragraph).enumerated()), id: \.offset) { i, token in
                                        tokenView(token, id: "\(index)-\(i)")
                                    }
                                }
                                if showTranslation, index < text.trans.count {
                                    Text(text.trans[index].text)
                                        .font(DS.text(15))
                                        .foregroundColor(DS.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.top, 22)
                    legend.padding(.top, 16)
                }
                .padding(.horizontal, DS.gutter)
                .padding(.top, 8)
                .padding(.bottom, selected == nil ? 120 : 300)
            }
            VStack(spacing: 12) {
                if let gloss = selected {
                    glossCard(gloss).transition(.move(edge: .bottom).combined(with: .opacity))
                }
                NavigationLink(value: AppRoute.readingQuiz(text.id)) {
                    HStack {
                        Text(quizTitle)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DS.gold)
                            .frame(width: 44, height: 44)
                            .background(DS.night, in: Circle())
                    }
                    .font(DS.text(16, .semibold))
                    .foregroundColor(DS.onGold)
                    .padding(.leading, 24)
                    .padding(.trailing, 8)
                    .frame(minHeight: 60)
                    .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 12)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selected)
        }
        .deschlyPage()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(showTranslation ? t("reading.hideTranslation") : t("reading.showTranslation")) {
                    showTranslation.toggle()
                }
                .font(DS.text(14, .semibold))
            }
        }
        .onAppear {
            daily.markRead(text)
            DispatchQueue.global(qos: .userInitiated).async { WordLookup.shared.prepare() }
        }
        .onDisappear { A1Speaker.shared.stop() }
    }

    private var player: some View {
        HStack(spacing: 12) {
            Button {
                if playing {
                    A1Speaker.shared.stop()
                    playing = false
                } else {
                    A1Speaker.shared.read(text.fullText, speed: speeds[speedIndex])
                    playing = true
                }
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DS.ground)
                    .frame(width: 48, height: 48)
                    .background(DS.ink, in: Circle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(playing ? t("reading.stop") : t("common.listen"))
            Text(playing ? t("reading.playing") : t("reading.listenText"))
                .font(DS.text(14, .medium))
                .foregroundColor(DS.muted)
            Spacer()
            Button(speedLabels[speedIndex]) {
                speedIndex = (speedIndex + 1) % speeds.count
                if playing { A1Speaker.shared.read(text.fullText, speed: speeds[speedIndex]) }
            }
            .font(DS.text(12, .semibold))
            .foregroundColor(DS.ink)
            .frame(minWidth: 52, minHeight: 34)
            .overlay(Capsule().stroke(DS.hairline, lineWidth: 1))
            .accessibilityLabel(t("reading.speed"))
        }
    }

    private struct Token {
        let text: String
        let gloss: DailyGloss?
    }

    private func tokens(_ paragraph: String) -> [Token] {
        paragraph.split(separator: " ").map { raw in
            let word = String(raw)
            let core = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:„“\"()–…")).lowercased()
            return Token(text: word, gloss: text.glossary.first { $0.form.lowercased() == core })
        }
    }

    /// Tap a marked word: the card below. Long-press any word: a bubble above it with meaning and pronunciation.
    private func tokenView(_ token: Token, id: String) -> some View {
        let open = bubbleID == id
        return Text(token.text)
            .font(DS.text(19))
            .foregroundColor(DS.ink)
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) {
                if let gloss = token.gloss {
                    Rectangle().fill(gloss.art.map(a1ArticleColor) ?? DS.muted).frame(height: 2)
                }
            }
            .background((open || (token.gloss != nil && selected == token.gloss)) ? DS.gold.opacity(0.25) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(alignment: .top) {
                if open {
                    wordBubble
                        .fixedSize()
                        .alignmentGuide(.top) { d in d[.bottom] + 8 }
                        .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                }
            }
            .zIndex(open ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture {
                bubbleID = nil
                if let gloss = token.gloss {
                    selected = gloss
                    A1Speaker.shared.say(gloss.display)
                }
            }
            .onLongPressGesture(minimumDuration: 0.35) { showBubble(token, id: id) }
            .accessibilityAddTraits(token.gloss != nil ? .isButton : [])
            .accessibilityHint(token.gloss != nil ? t("reading.tapHint") : t("reading.holdHint"))
            .accessibilityAction(named: Text(t("reading.holdAction"))) { showBubble(token, id: id) }
    }

    private func showBubble(_ token: Token, id: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let info = WordLookup.shared.info(for: token.text, glossary: text.glossary)
        bubbleWord = token.text.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:„“\"()–…‚‘'»«"))
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            bubble = info
            bubbleID = id
        }
        A1Speaker.shared.say(info.map { ($0.article.map { "\($0) " } ?? "") + $0.word } ?? bubbleWord)
        // Close by itself after a while, unless another word was opened.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if bubbleID == id { withAnimation(.easeOut(duration: 0.2)) { bubbleID = nil } }
        }
    }

    private var wordBubble: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let article = bubble?.article {
                    Text(article).font(.system(size: 14, weight: .heavy)).foregroundColor(a1ArticleColor(article))
                }
                Text(bubble?.word ?? bubbleWord).font(.system(size: 17, weight: .bold)).foregroundColor(DS.onNight)
            }
            if let pron = bubble?.pron, !pron.isEmpty, a1ShowsPron() {
                Text("[\(pron)]").font(.system(size: 13)).foregroundColor(DS.onNightMuted)
            }
            Text(bubble?.meaning ?? t("reading.notInDictionary"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(bubble == nil ? DS.onNightMuted : DS.gold)
                .frame(maxWidth: 220, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let extra = bubble?.extra {
                Text(extra).font(.system(size: 12)).foregroundColor(DS.onNightMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(DS.night, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .bottom) {
            Triangle().fill(DS.night).frame(width: 14, height: 7).offset(y: 7)
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(["der", "die", "das"], id: \.self) { art in
                HStack(spacing: 6) {
                    Rectangle().fill(a1ArticleColor(art)).frame(width: 14, height: 3)
                    Text(art)
                }
            }
            Text(t("reading.legend"))
        }
        .font(DS.text(12))
        .foregroundColor(DS.muted)
    }

    private var quizTitle: String {
        switch daily.status(text) {
        case .done: return t("reading.quizDone")
        case .tried(let score): return t("reading.quizRetry", score)
        default: return t("reading.quiz")
        }
    }

    private func glossCard(_ gloss: DailyGloss) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let art = gloss.art {
                    Text(art).font(DS.text(15, .semibold)).foregroundColor(art == "der" ? Color(red: 0.56, green: 0.66, blue: 1) : art == "die" ? Color(red: 1, green: 0.54, blue: 0.56) : Color(red: 0.37, green: 0.82, blue: 0.54))
                }
                Text(gloss.lemma).font(DS.display(26, heavy: false)).foregroundColor(DS.onNight)
                Spacer()
                Button { selected = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DS.onNight)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(t("common.close"))
            }
            let details = [gloss.pron.flatMap { a1ShowsPron() ? "[\($0)]" : nil }, gloss.extra].compactMap { $0 }
            if !details.isEmpty {
                Text(details.joined(separator: " · ")).font(DS.text(13)).foregroundColor(DS.onNightMuted)
            }
            Text(gloss.mean.text).font(DS.text(17, .semibold)).foregroundColor(DS.onNight)
            HStack(spacing: 8) {
                Button {
                    daily.toggleSaved(gloss)
                } label: {
                    Label(daily.isSaved(gloss) ? t("reading.saved") : t("reading.save"),
                          systemImage: daily.isSaved(gloss) ? "checkmark" : "plus")
                        .font(DS.text(14, .semibold))
                        .foregroundColor(DS.onGold)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
                Button {
                    A1Speaker.shared.say(gloss.display, slow: true)
                } label: {
                    Label(t("common.listen"), systemImage: "speaker.wave.2")
                        .font(DS.text(14, .medium))
                        .foregroundColor(DS.onNight)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.pressable)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(DS.night, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }
}

/// Reading tab: today's text, earlier days and the A1 workbook texts, as a native grouped list.
struct ReadingHomeView: View {
    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var a1: A1Model

    var body: some View {
        List {
            if let today = daily.today {
                Section(t("reading.today")) {
                    NavigationLink(value: AppRoute.reading(today.id)) { row(today, note: nil, large: true) }
                }
            }
            let archive = daily.archive()
            if !archive.isEmpty {
                Section(t("reading.archive")) {
                    ForEach(Array(archive.enumerated()), id: \.offset) { _, item in
                        NavigationLink(value: AppRoute.reading(item.text.id)) {
                            row(item.text, note: item.date.formatted(.dateTime.day().month(.abbreviated)), large: false)
                        }
                    }
                }
            }
            Section {
                NavigationLink(value: AppRoute.savedWords) {
                    HStack {
                        Label(t("saved.title"), systemImage: "bookmark.fill")
                        Spacer()
                        Text("\(daily.state.savedWords.count)").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
            Section(t("reading.more")) {
                NavigationLink(value: A1Route.texts) {
                    Label(t("practice.texts", a1.content?.texts.count ?? 0), systemImage: "doc.richtext")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(t("reading.title"))
        .safeAreaInset(edge: .bottom) { AdBanner() }
    }

    private func row(_ text: DailyText, note: String?, large: Bool) -> some View {
        HStack(spacing: 12) {
            if let cover = Covers.image(text.id) {
                CoverImage(image: cover, height: large ? 64 : 48, radius: 10).frame(width: large ? 96 : 72)
            } else {
                Image(systemName: "book.closed")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: large ? 64 : 48, height: large ? 64 : 48)
                    .background(DS.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(text.title).font(large ? .headline : .body)
                Text([note, "\(text.level) · \(text.topic) · \(text.minutes) min"].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            switch daily.status(text) {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DS.success)
                    .accessibilityLabel(t("reading.statusDone"))
            case .tried(let score):
                Text("\(score)%")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(DS.goldDeep)
                    .accessibilityLabel(t("reading.statusTried", score))
            case .opened:
                Image(systemName: "circle.dashed")
                    .foregroundColor(.secondary)
                    .accessibilityLabel(t("reading.statusOpened"))
            case .new:
                EmptyView()
            }
        }
        .padding(.vertical, large ? 4 : 0)
    }
}

/// Words the learner saved while reading: listen, delete, quiz.
struct SavedWordsView: View {
    @EnvironmentObject private var daily: DailyModel

    var body: some View {
        let items = daily.savedGlosses
        List {
            if items.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark").font(.largeTitle).foregroundStyle(.secondary)
                        Text(t("saved.empty")).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    NavigationLink(value: AppRoute.savedWordsQuiz) {
                        Label(t("saved.quiz", items.count), systemImage: "play.circle.fill")
                    }
                    .disabled(items.count < 2)
                }
                Section {
                    ForEach(items, id: \.gloss.display) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                (Text(item.gloss.art.map { $0 + " " } ?? "").foregroundColor(item.gloss.art.map(a1ArticleColor) ?? DS.ink)
                                    + Text(item.gloss.lemma))
                                    .font(.body.weight(.semibold))
                                Text(item.gloss.mean.text).font(.subheadline)
                                Text([item.gloss.pron.flatMap { a1ShowsPron() ? "[\($0)]" : nil }, item.text.title]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            A1SpeakButton(text: item.gloss.display)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { daily.removeSaved(items[i].gloss.display) }
                    }
                } footer: {
                    Text(t("saved.footer"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(t("saved.title"))
        .toolbar { if !items.isEmpty { EditButton() } }
    }
}

/// The little arrow under the word bubble.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
