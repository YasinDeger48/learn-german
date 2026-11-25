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
    /// The iPhone voice is reading (the recorded voices report their own state).
    @State private var deviceReading = false
    @State private var speedIndex = 0
    @AppStorage(ReadingVoice.storageKey) private var voiceRaw = ReadingVoice.female.rawValue
    @ObservedObject private var audio = TextAudioPlayer.shared
    @ObservedObject private var ambience = AmbiencePlayer.shared
    @State private var deviceStarted = Date.distantPast
    /// The iPhone voice has no "finished" event here: check now and then.
    private let speechClock = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()
    @State private var voiceNote: String?
    /// Long-press bubble: token id and what it shows.
    @State private var bubbleID: String?
    @State private var bubble: WordInfo?
    @State private var bubbleWord = ""
    /// Where the pressed word is on screen and how big the bubble is, to keep the bubble inside the screen.
    @State private var bubbleAnchor: CGRect = .zero
    @State private var bubbleSize: CGSize = .zero
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
            ambience.load()
            DispatchQueue.global(qos: .userInitiated).async { WordLookup.shared.prepare() }
        }
        .onDisappear { stopReading() }
        .onChange(of: audio.playing) { playing in
            if !playing && !deviceReading && !audio.loading { ambience.stop() }
        }
        .onReceive(speechClock) { _ in
            if deviceReading, Date().timeIntervalSince(deviceStarted) > 1.5, !A1Speaker.shared.isSpeaking {
                deviceReading = false
                ambience.stop()
            }
        }
    }

    private var voice: ReadingVoice { ReadingVoice.from(voiceRaw) }
    private var isPlaying: Bool { audio.playing || deviceReading }

    private func togglePlay() {
        if isPlaying || audio.loading {
            stopReading()
            return
        }
        voiceNote = nil
        ambience.start(textID: text.id)
        if voice == .device {
            readWithDevice()
        } else {
            audio.play(textID: text.id, voice: voice, speed: speeds[speedIndex]) {
                voiceNote = t("voice.fallback")
                readWithDevice()
            }
        }
    }

    private func readWithDevice() {
        A1Speaker.shared.read(text.fullText, speed: speeds[speedIndex])
        deviceStarted = Date()
        deviceReading = true
    }

    private func stopReading() {
        audio.stop()
        A1Speaker.shared.stop()
        ambience.stop()
        deviceReading = false
    }

    /// Background sound on/off; only for texts that have one.
    @ViewBuilder
    private var ambienceButton: some View {
        if ambience.kind(for: text.id) != nil {
            Button {
                ambience.enabled.toggle()
                if ambience.enabled {
                    if isPlaying { ambience.start(textID: text.id) }
                } else {
                    ambience.stop()
                }
            } label: {
                Image(systemName: ambience.enabled ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(ambience.enabled ? DS.goldDeep : DS.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("ambience.toggle"))
            .accessibilityValue(ambience.enabled ? t("ambience.onValue") : t("ambience.offValue"))
        }
    }

    private func choose(_ newVoice: ReadingVoice) {
        let wasPlaying = isPlaying
        voiceRaw = newVoice.rawValue
        if wasPlaying {
            stopReading()
            togglePlay()
        }
    }

    private var voiceMenu: some View {
        Menu {
            ForEach(ReadingVoice.choices) { option in
                Button { choose(option) } label: {
                    Label {
                        Text(option.title)
                        Text(option.subtitle)
                    } icon: {
                        Image(systemName: option == voice ? "checkmark" : option.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: voice.icon).font(.system(size: 11, weight: .bold))
                Text(voice.title).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .font(DS.text(13, .semibold))
            .foregroundColor(DS.ink)
        }
        .accessibilityLabel(t("voice.choose"))
    }

    private var player: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button { togglePlay() } label: {
                    ZStack {
                        if audio.loading {
                            ProgressView().tint(DS.ground)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(DS.ground)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .background(DS.ink, in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(isPlaying ? t("reading.stop") : t("common.listen"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(isPlaying ? t("reading.playing") : t("reading.listenText"))
                        .font(DS.text(12, .medium))
                        .foregroundColor(DS.muted)
                    voiceMenu
                }
                Spacer()
                ambienceButton
                Button(speedLabels[speedIndex]) {
                    speedIndex = (speedIndex + 1) % speeds.count
                    if audio.playing {
                        audio.setSpeed(speeds[speedIndex])
                    } else if deviceReading {
                        A1Speaker.shared.read(text.fullText, speed: speeds[speedIndex])
                    }
                }
                .font(DS.text(12, .semibold))
                .foregroundColor(DS.ink)
                .frame(minWidth: 52, minHeight: 34)
                .overlay(Capsule().stroke(DS.hairline, lineWidth: 1))
                .accessibilityLabel(t("reading.speed"))
            }
            if audio.playing {
                ProgressView(value: audio.progress).tint(DS.gold)
            }
            if ambience.enabled, let kind = ambience.kind(for: text.id) {
                Label(t("ambience.on", t("ambience.kind.\(kind)")), systemImage: "waveform")
                    .font(DS.text(12, .medium))
                    .foregroundColor(DS.goldDeep)
            }
            if let voiceNote {
                Text(voiceNote).font(DS.text(12)).foregroundColor(DS.muted)
            }
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
            .background {
                if open {
                    GeometryReader { g in
                        Color.clear
                            .onAppear { bubbleAnchor = g.frame(in: .global) }
                            .onChange(of: g.frame(in: .global)) { bubbleAnchor = $0 }
                    }
                }
            }
            .overlay(alignment: .top) {
                if open {
                    let below = bubbleBelow
                    wordBubble(below: below)
                        .fixedSize()
                        .background(GeometryReader { g in
                            Color.clear
                                .onAppear { bubbleSize = g.size }
                                .onChange(of: g.size) { bubbleSize = $0 }
                        })
                        .offset(x: bubbleShift)
                        .alignmentGuide(.top) { d in below ? d[.top] - bubbleAnchor.height - 8 : d[.bottom] + 8 }
                        .transition(.scale(scale: 0.85, anchor: below ? .top : .bottom).combined(with: .opacity))
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

    /// Moves the bubble sideways so it stays 12 pt inside the screen edges.
    private var bubbleShift: CGFloat {
        let width = bubbleSize.width
        guard width > 0, bubbleAnchor.width > 0 else { return 0 }
        let screen = UIScreen.main.bounds.width
        let margin: CGFloat = 12
        let left = bubbleAnchor.midX - width / 2
        let fitted = min(max(left, margin), max(margin, screen - margin - width))
        return fitted - left
    }

    /// Opens below the word when there is no room above it (under the navigation bar).
    private var bubbleBelow: Bool {
        guard bubbleAnchor.height > 0 else { return false }
        let top = (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?
            .windows.first?.safeAreaInsets.top ?? 47) + 44
        return bubbleAnchor.minY - (bubbleSize.height > 0 ? bubbleSize.height : 90) - 12 < top
    }

    private func wordBubble(below: Bool) -> some View {
        // The arrow stays over the word even when the bubble moved sideways.
        let arrowX = max(-(bubbleSize.width / 2 - 20), min(bubbleSize.width / 2 - 20, -bubbleShift))
        let meaning = bubble?.meaning ?? t("reading.notInDictionary")
        // The bubble is sized to its content (fixedSize), so a long line would run out of it:
        // long content gets a fixed width and wraps instead.
        let longest = [bubble?.word ?? bubbleWord, meaning, bubble?.extra ?? ""].map(\.count).max() ?? 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let article = bubble?.article {
                    Text(article).font(.system(size: 14, weight: .heavy)).foregroundColor(a1ArticleColor(article))
                }
                Text(bubble?.word ?? bubbleWord).font(.system(size: 17, weight: .bold)).foregroundColor(DS.onNight)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let pron = bubble?.pron, !pron.isEmpty, a1ShowsPron() {
                Text("[\(pron)]").font(.system(size: 13)).foregroundColor(DS.onNight.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(meaning)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(bubble == nil ? DS.onNight.opacity(0.8) : DS.gold)
                .fixedSize(horizontal: false, vertical: true)
            if let extra = bubble?.extra {
                Text(extra).font(.system(size: 13)).foregroundColor(DS.onNight.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: longest > 24 ? 240 : nil, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(DS.night, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: below ? .top : .bottom) {
            Triangle().fill(DS.night).frame(width: 14, height: 7)
                .rotationEffect(.degrees(below ? 180 : 0))
                .offset(x: bubbleSize.width > 0 ? arrowX : 0, y: below ? -7 : 7)
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

/// Reading tab: today's text as a big cover card, progress in the level, earlier days as a carousel,
/// every text of the level, saved words and the workbook texts.
struct ReadingHomeView: View {
    @EnvironmentObject private var daily: DailyModel
    @EnvironmentObject private var a1: A1Model

    var body: some View {
        let all = daily.allTexts()
        let done = all.filter { daily.isCompleted($0) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let today = daily.today {
                    NavigationLink(value: AppRoute.reading(today.id)) { todayCard(today) }
                        .buttonStyle(.pressable)
                }
                if !all.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(t("reading.levelProgress", daily.level)).font(.headline)
                            Spacer()
                            Text("\(done)/\(all.count)").font(.subheadline.weight(.semibold).monospacedDigit()).foregroundColor(DS.success)
                        }
                        ProgressView(value: Double(done), total: Double(max(1, all.count))).tint(DS.success)
                        Text(t("reading.levelProgressNote")).font(.footnote).foregroundColor(DS.muted)
                    }
                    .padding(16)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                let archive = daily.archive()
                if !archive.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("reading.archive")).font(.title3.weight(.bold))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(archive.enumerated()), id: \.offset) { _, item in
                                    NavigationLink(value: AppRoute.reading(item.text.id)) {
                                        TextTile(text: item.text, note: item.date.formatted(.dateTime.day().month(.abbreviated)))
                                            .frame(width: 168)
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                            .padding(.horizontal, DS.gutter)
                        }
                        .padding(.horizontal, -DS.gutter)
                    }
                }
                VStack(spacing: 0) {
                    NavigationLink(value: AppRoute.allTexts) {
                        menuRow("square.grid.2x2.fill", DS.accent, t("reading.allTexts", daily.level), "\(all.count)")
                    }
                    Divider().padding(.leading, 52)
                    NavigationLink(value: AppRoute.savedWords) {
                        menuRow("bookmark.fill", DS.goldDeep, t("saved.title"), "\(daily.state.savedWords.count)")
                    }
                    Divider().padding(.leading, 52)
                    NavigationLink(value: A1Route.texts) {
                        menuRow("doc.richtext.fill", .teal, t("practice.texts", a1.content?.texts.count ?? 0), nil)
                    }
                }
                .buttonStyle(.pressable)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("reading.title"))
        .safeAreaInset(edge: .bottom) { AdBanner() }
    }

    private func todayCard(_ text: DailyText) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let cover = Covers.image(text.id) {
                    Image(uiImage: cover).resizable().scaledToFill()
                        .frame(height: 190).frame(maxWidth: .infinity).clipped()
                } else {
                    LinearGradient(colors: [DS.accent, DS.night], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 120)
                }
                Text(t("reading.today").uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(DS.onGold)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(DS.gold, in: Capsule())
                    .padding(12)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("\(text.level) · \(text.topic) · \(text.minutes) min").font(.footnote).foregroundColor(DS.onNightMuted)
                Text(text.title).font(DS.display(24)).foregroundColor(DS.onNight).lineLimit(2)
                HStack {
                    ReadingStatusBadge(status: daily.status(text), dark: true)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DS.onGold)
                        .frame(width: 40, height: 40)
                        .background(DS.gold, in: Circle())
                }
            }
            .padding(16)
        }
        .background(DS.night)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func menuRow(_ icon: String, _ color: Color, _ title: String, _ value: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(color).frame(width: 26)
            Text(title).foregroundColor(DS.ink)
            Spacer(minLength: 6)
            if let value { Text(value).font(.subheadline.monospacedDigit()).foregroundColor(DS.muted) }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

/// Status of a daily text as a small label: done, quiz score, opened or new.
struct ReadingStatusBadge: View {
    let status: ReadingStatus
    var dark = false

    var body: some View {
        switch status {
        case .done:
            Label(t("reading.statusDoneShort"), systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold)).foregroundColor(DS.success)
        case .tried(let score):
            Label(t("reading.statusTriedShort", score), systemImage: "arrow.clockwise")
                .font(.caption.weight(.semibold)).foregroundColor(dark ? DS.gold : DS.goldDeep)
        case .opened:
            Label(t("reading.statusOpenedShort"), systemImage: "circle.dashed")
                .font(.caption).foregroundColor(dark ? DS.onNightMuted : DS.muted)
        case .new:
            Label(t("reading.statusNew"), systemImage: "sparkles")
                .font(.caption.weight(.semibold)).foregroundColor(dark ? DS.onNight : DS.accent)
        }
    }
}

/// A text as a small card with its cover, for carousels and grids.
struct TextTile: View {
    @EnvironmentObject private var daily: DailyModel
    let text: DailyText
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let cover = Covers.image(text.id) {
                    Image(uiImage: cover).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [DS.accent.opacity(0.85), DS.night], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(Image(systemName: "book.closed").font(.title2).foregroundColor(.white.opacity(0.8)))
                }
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(text.title).font(.system(size: 14, weight: .bold)).foregroundColor(DS.ink).lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
                Text(note ?? text.topic).font(.caption2).foregroundColor(DS.muted).lineLimit(1)
                ReadingStatusBadge(status: daily.status(text))
            }
            .padding(10)
        }
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Every daily text of the learner's level, newest unread first, with a filter.
struct AllTextsView: View {
    @EnvironmentObject private var daily: DailyModel
    @State private var filter = 0

    var body: some View {
        let all = daily.allTexts()
        let shown: [DailyText] = {
            switch filter {
            case 1: return all.filter { !daily.isCompleted($0) }
            case 2: return all.filter { daily.isCompleted($0) }
            default: return all
            }
        }()
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("", selection: $filter) {
                    Text(t("grammar.filterAll")).tag(0)
                    Text(t("reading.filterOpen")).tag(1)
                    Text(t("reading.filterDone")).tag(2)
                }
                .pickerStyle(.segmented)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(shown) { text in
                        NavigationLink(value: AppRoute.reading(text.id)) { TextTile(text: text) }
                            .buttonStyle(.pressable)
                    }
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("reading.allTexts", daily.level))
        .navigationBarTitleDisplayMode(.inline)
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
