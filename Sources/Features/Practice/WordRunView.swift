import SwiftUI

// MARK: - Kelime koşusu (word run)
// Lina runs through the Swiss Alps; a box with a word picture stops her, the learner picks the German word (2×2),
// a right answer makes her jump over the box and run on, a wrong one makes her stumble (no penalty, try again).
// 10 boxes, then the finish with Lina's heart. Pictures by Codex (icerik/gorseller/LINA_KOSU.txt), prepared by
// tools/images/runner_assets.py. Design: https://claude.ai/artifact/WLKZGCFYSCuLJMo6uuz2i2

/// Nouns of a level that have a picture: A1 picture cards (wp-<level>-<id>) and unit word pictures (wv-<slug>).
/// Built once per level (it checks many files).
enum WordPictureBank {
    struct Item: Identifiable, Equatable {
        let id: String
        let art: String
        let word: String
        let meaning: String
        let picture: String
        var full: String { "\(art) \(word)" }
    }

    private static var cache: [String: [Item]] = [:]

    static func items(level: String, content: A1Content?) -> [Item] {
        if let known = cache[level] { return known }
        var out: [Item] = []
        var meanings = Set<String>()
        func add(_ item: Item) {
            guard !item.meaning.isEmpty, meanings.insert(item.meaning.lowercased()).inserted else { return }
            out.append(item)
        }
        for word in content?.words ?? [] where word.isNoun {
            let card = "wp-\(level.lowercased())-\(word.id)"
            let noun = slug(word.de)
            let picture = Covers.exists(card) ? card : (Covers.exists(noun) ? noun : nil)
            if let picture { add(Item(id: "w\(word.id)", art: word.type, word: word.de, meaning: word.mean.text, picture: picture)) }
        }
        for unit in UnitBank.units(level) {
            for word in unit.vocab ?? [] {
                guard let art = word.art, let name = word.picture, Covers.exists(name) else { continue }
                add(Item(id: "v\(name)", art: art, word: word.de, meaning: word.meaning, picture: name))
            }
        }
        cache[level] = out
        return out
    }

    static func slug(_ word: String) -> String {
        var s = word.lowercased()
        for (from, to) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] { s = s.replacingOccurrences(of: from, with: to) }
        return "wv-" + s.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.joined(separator: "-")
    }
}

private struct RunQuestion {
    let item: WordPictureBank.Item
    let options: [WordPictureBank.Item]
}

/// The game pictures, loaded once.
private enum RunArt {
    static let far = UIImage(named: "kosu-uzak.jpg")
    static let middle = UIImage(named: "kosu-orta")
    static let near = UIImage(named: "kosu-yakin")
    static let box = UIImage(named: "kosu-kutu")
    static let run = (1...4).compactMap { UIImage(named: "lina-run-\($0)") }
    static let jump = UIImage(named: "lina-jump")
    static let stumble = UIImage(named: "lina-stumble")
    static let finish = UIImage(named: "lina-finish")
}

struct WordRunView: View {
    @EnvironmentObject private var model: A1Model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case arriving, waiting, jumping, stumbling, finished }
    /// Box counts to choose from before the run.
    private static let counts = [5, 10, 15, 20]
    private static let speed: Double = 170          // points per second on the near layer
    /// Room the answers need under the scene: the question row, the 2×2 options and the meaning box.
    private static let answersHeight: CGFloat = 340

    @State private var questions: [RunQuestion] = []
    /// Before the run: which words (all of the level or the learner's pool) and how many boxes.
    @State private var choosing = true
    @AppStorage("run.usePool") private var usePool = false
    @AppStorage("run.count") private var chosenCount = 10
    @State private var boxes = 10
    @State private var index = 0
    @State private var phase: Phase = .arriving
    @State private var distanceBase: Double = 0
    @State private var movingSince: Date?
    @State private var boxX: CGFloat = 420
    @State private var boxGone = false
    @State private var jump: CGSize = .zero
    @State private var shake: CGFloat = 0
    @State private var rightID: String?
    @State private var wrongID: String?
    @State private var score = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var done = 0
    @State private var gain = ""
    @State private var heartBeat = false
    /// The meaning box under the options: the last answered word (right, or the wrong pick), or all four meanings.
    @State private var lastWord: WordPictureBank.Item?
    @State private var lastRight = true
    @AppStorage("run.showMeanings") private var showAllMeanings = false

    private static let ink = Color(red: 0.055, green: 0.059, blue: 0.047)
    private static let soft = Color(red: 0.42, green: 0.41, blue: 0.38)

    var body: some View {
        ZStack {
            Color(red: 0.992, green: 0.973, blue: 0.918).ignoresSafeArea()
            if choosing {
                setup
            } else if questions.isEmpty {
                ProgressView()
            } else {
                // The answers keep their size; the scene takes what is left, 400 at most (small phones: from 230).
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        scene.frame(height: min(400, max(230, proxy.size.height - Self.answersHeight)))
                        answers
                        Spacer(minLength: 0)
                    }
                }
            }
            if phase == .finished { finishView.transition(.opacity) }
        }
        .environment(\.colorScheme, .light)
        .navigationTitle(t("run.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { A1Speaker.shared.stop() }
    }

    // MARK: Setup

    /// Every word with a picture in the level (wrong options always come from here).
    private var levelItems: [WordPictureBank.Item] { WordPictureBank.items(level: model.level, content: model.content) }

    /// The pictured words of the learner's pool (Kelimelerim → Havuzum; level words have the id "w<word id>").
    private var poolItems: [WordPictureBank.Item] {
        let pool = LazyPool.ids(model.level)
        return levelItems.filter { $0.id.hasPrefix("w") && pool.contains(Int($0.id.dropFirst()) ?? -1) }
    }

    private var setup: some View {
        let all = levelItems
        let mine = poolItems
        let fromPool = usePool && !mine.isEmpty
        let counts = countChoices(fromPool ? mine.count : all.count)
        let selected = boxCount(counts)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let image = RunArt.run.first {
                    Image(uiImage: image).resizable().scaledToFit().frame(height: 150)
                        .frame(maxWidth: .infinity).accessibilityHidden(true)
                }
                Text(t("run.setupWhich")).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                VStack(spacing: 8) {
                    sourceRow(false, title: t("run.setupLevel", model.level), sub: t("run.setupLevelSub", all.count), enabled: true)
                    sourceRow(true, title: t("run.setupPool"),
                              sub: mine.isEmpty ? t("run.setupPoolEmpty") : t("run.setupPoolSub", mine.count), enabled: !mine.isEmpty)
                }
                Text(t("run.setupCount")).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                    .padding(.top, 6)
                HStack(spacing: 8) {
                    ForEach(counts, id: \.self) { n in
                        let on = n == selected
                        Button { chosenCount = n } label: {
                            Text("\(n)").font(.system(size: 17, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundColor(Self.ink)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(on ? DS.gold : Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(on ? Color.clear : Color.black.opacity(0.08)))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                Button { restart() } label: {
                    Text(t("run.setupStart")).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(all.count < 4)
                .padding(.top, 10)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 12)
        }
    }

    /// 5, 10, 15, 20 as far as there are words; fewer than 5 words: just that number.
    private func countChoices(_ available: Int) -> [Int] {
        let fitting = Self.counts.filter { $0 <= available }
        return fitting.isEmpty ? [max(1, available)] : fitting
    }

    /// The chosen count, or the biggest one that fits.
    private func boxCount(_ counts: [Int]) -> Int { counts.contains(chosenCount) ? chosenCount : (counts.last ?? 10) }

    private func sourceRow(_ pool: Bool, title: String, sub: String, enabled: Bool) -> some View {
        let on = enabled && (usePool == pool)
        return Button { usePool = pool } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22)).foregroundColor(on ? DS.goldDeep : Self.soft)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Self.ink)
                    Text(sub).font(.system(size: 13, design: .rounded)).foregroundColor(Self.soft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? DS.gold : Color.black.opacity(0.06), lineWidth: on ? 2 : 1))
            .opacity(enabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Scene

    private var scene: some View {
        TimelineView(.animation(paused: movingSince == nil || reduceMotion)) { timeline in
            let distance = currentDistance(timeline.date)
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    layer(RunArt.far, height: geo.size.height, factor: 0.06, distance: distance)
                    layer(RunArt.middle, height: 165, factor: 0.32, distance: distance).padding(.bottom, 62)
                    layer(RunArt.near, height: 150, factor: 1, distance: distance)
                    lina(timeline.date).padding(.leading, 18).padding(.bottom, 6)
                    box.padding(.leading, geo.size.width * 0.6).padding(.bottom, 14)
                    if phase == .jumping, !gain.isEmpty {
                        Text(gain)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color(red: 0.79, green: 0.60, blue: 0.12), radius: 0, y: 2)
                            .padding(.leading, geo.size.width * 0.62)
                            .padding(.bottom, 150)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
                .clipped()
            }
        }
        // The world always runs left to right (the art faces right); in Arabic the layout would mirror it and
        // Lina would run backwards. The HUD and the answers keep the user's direction.
        .environment(\.layoutDirection, .leftToRight)
        .modifier(RunShake(amount: shake))
        .overlay(alignment: .top) { hud }
    }

    /// One endless layer: the picture, then its mirror, and again, so the edges always meet.
    private func layer(_ image: UIImage?, height: CGFloat, factor: Double, distance: Double) -> some View {
        GeometryReader { geo in
            if let image, image.size.height > 0 {
                let tile = height * image.size.width / image.size.height
                let shift = CGFloat((distance * factor).truncatingRemainder(dividingBy: Double(tile * 2)))
                HStack(spacing: 0) {
                    ForEach(0..<(Int(geo.size.width / tile) + 3), id: \.self) { i in
                        Image(uiImage: image).resizable()
                            .frame(width: tile, height: height)
                            .scaleEffect(x: i % 2 == 0 ? 1 : -1, y: 1)
                    }
                }
                .offset(x: -shift)
                .frame(width: geo.size.width, height: height, alignment: .leading)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func lina(_ date: Date) -> some View {
        let image: UIImage? = {
            switch phase {
            case .jumping: return RunArt.jump
            case .stumbling: return RunArt.stumble
            case .waiting, .finished: return RunArt.run.first
            case .arriving:
                guard !RunArt.run.isEmpty else { return nil }
                return RunArt.run[Int(date.timeIntervalSinceReferenceDate * 9) % RunArt.run.count]
            }
        }()
        return ZStack(alignment: .top) {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            if phase == .stumbling {
                DizzyStars().frame(width: 70, height: 40).offset(x: 6, y: 8)
            }
        }
        .frame(width: 168, height: 168)
        .offset(x: jump.width, y: jump.height)
        .accessibilityLabel(t("run.lina"))
    }

    private var box: some View {
        let picture = questions.indices.contains(index) ? Covers.image(questions[index].item.picture) : nil
        // The box picture's white window is a square of 51 % of the box, its middle 8.5 pt below the box's middle:
        // the word picture sits on its own white card there, clipped, so it never spills over the box.
        return ZStack {
            if let image = RunArt.box { Image(uiImage: image).resizable().scaledToFit() }
            if let picture {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 55, height: 55)
                    .overlay(
                        Image(uiImage: picture).resizable().scaledToFit()
                            .frame(width: 47, height: 47)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .offset(y: 8.5)
            }
        }
        .frame(width: 112, height: 112)
        .rotationEffect(.degrees(boxGone ? -320 : 0))
        .offset(x: boxGone ? -520 : boxX, y: boxGone ? -60 : 0)
        .opacity(boxGone ? 0 : 1)
        .accessibilityLabel(t("run.box"))
    }

    /// One glassy bar over the sky: boxes done, a track of ten steps with Lina's marker running along it to the flag,
    /// and the score.
    private var hud: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Image(systemName: "shippingbox.fill").font(.system(size: 13, weight: .bold)).foregroundColor(DS.gold)
                Text("\(done)/\(boxes)").font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
            }
            GeometryReader { proxy in
                let fraction = CGFloat(done) / CGFloat(boxes)
                ZStack(alignment: .leading) {
                    HStack(spacing: 3) {
                        ForEach(0..<boxes, id: \.self) { step in
                            Capsule()
                                .fill(step < done ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.54), DS.gold],
                                                                                 startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(Color.white.opacity(step == done ? 0.55 : 0.22)))
                                .frame(height: 8)
                        }
                    }
                    Image(systemName: "figure.run")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Self.ink)
                        .frame(width: 24, height: 24)
                        .background(Color.white, in: Circle())
                        .overlay(Circle().stroke(DS.gold, lineWidth: 2))
                        .offset(x: max(0, min(proxy.size.width - 24, proxy.size.width * fraction - 12)))
                }
                .frame(height: 24)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 24)
            .overlay(alignment: .trailing) {
                Image(systemName: "flag.checkered").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    .offset(x: 14)
            }
            .padding(.trailing, 14)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: done)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(t("run.boxes", done, boxes))
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 12, weight: .bold))
                Text("\(score)").font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .foregroundColor(Self.ink)
            .padding(.horizontal, 11)
            .frame(minHeight: 32)
            .background(DS.gold, in: Capsule())
            .animation(.easeOut(duration: 0.3), value: score)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 46)
        .background(Color.black.opacity(0.38), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .overlay(alignment: .bottomLeading) {
            if streak >= 2 {
                Label("x\(streak) " + t("match.streak"), systemImage: "flame.fill")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(red: 1, green: 0.48, blue: 0.27), in: Capsule())
                    .offset(x: 16, y: 40)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: Answers

    private var answers: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("run.question")).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                    Text(phase == .stumbling ? t("run.oops") : t("run.hint"))
                        .font(.system(size: 13, design: .rounded)).foregroundColor(Self.soft)
                }
                Spacer()
                Button {
                    if questions.indices.contains(index) { A1Speaker.shared.say(questions[index].item.full) }
                } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 18, weight: .bold)).foregroundColor(DS.gold)
                        .frame(width: 48, height: 48).background(Self.ink, in: Circle())
                }
                .accessibilityLabel(t("run.listen"))
            }
            if questions.indices.contains(index) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(questions[index].options) { option in optionButton(option) }
                }
                meaningBox(questions[index].options)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    /// Under the options: what the last answered word means in the learner's language (owner's request), or, with
    /// the eye on, the meaning of all four options (a help for beginners; off by default so the picture stays a riddle).
    private func meaningBox(_ options: [WordPictureBank.Item]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                if showAllMeanings {
                    ForEach(options) { option in
                        HStack(spacing: 6) {
                            Text(option.art).font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundColor(a1ArticleColor(option.art))
                            Text(option.word).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(Self.ink)
                            Text("= " + option.meaning).font(.system(size: 15, design: .rounded)).foregroundColor(Self.soft).lineLimit(1)
                        }
                    }
                } else if let word = lastWord {
                    HStack(spacing: 6) {
                        Image(systemName: lastRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(lastRight ? DS.das : Color(red: 0.89, green: 0.36, blue: 0.36))
                        Text(word.art).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(a1ArticleColor(word.art))
                        Text(word.word).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(Self.ink)
                    }
                    Text(word.meaning).font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.21))
                } else {
                    Text(t("run.meaningHint")).font(.system(size: 14, design: .rounded)).foregroundColor(Self.soft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showAllMeanings.toggle() }
            } label: {
                Image(systemName: showAllMeanings ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Self.ink)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.949, green: 0.933, blue: 0.886), in: Circle())
            }
            .accessibilityLabel(showAllMeanings ? t("run.hideMeanings") : t("run.showMeanings"))
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(red: 0.886, green: 0.863, blue: 0.784), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private func optionButton(_ option: WordPictureBank.Item) -> some View {
        let isRight = rightID == option.id
        let isWrong = wrongID == option.id
        return Button { pick(option) } label: {
            HStack(spacing: 8) {
                Text(option.art)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 34, minHeight: 26)
                    .background(a1ArticleColor(option.art), in: Capsule())
                Text(option.word)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Self.ink)
                    .lineLimit(2).minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 72)
            // The raised edge is drawn under the card only: a shadow on the whole button doubled the text.
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isRight ? Color(red: 0.867, green: 0.961, blue: 0.898) : (isWrong ? Color(red: 1, green: 0.894, blue: 0.894) : .white))
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(red: 0.886, green: 0.863, blue: 0.784)).offset(y: 5))
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isRight ? DS.das : (isWrong ? Color(red: 0.89, green: 0.36, blue: 0.36) : .clear), lineWidth: 3))
        }
        .buttonStyle(.pressable)
        .disabled(phase != .waiting)
        .accessibilityLabel("\(option.art) \(option.word)")
    }

    // MARK: Finish

    private var finishView: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 0) {
                if let image = RunArt.finish {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(height: 260)
                        .scaleEffect(heartBeat ? 1.04 : 1, anchor: .bottom)
                        .accessibilityLabel(t("run.finishLina"))
                        .zIndex(1)
                        .offset(y: 40)
                }
                VStack(spacing: 6) {
                    Text("Ziel erreicht!").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                    Text(t("run.finishSub", boxes, score, max(1, bestStreak)))
                        .font(.system(size: 15, design: .rounded)).foregroundColor(Self.soft).multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        Button { dismiss() } label: {
                            Text(t("match.finish")).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Self.ink)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(Color(red: 0.949, green: 0.933, blue: 0.886), in: Capsule())
                        }
                        Button { restart() } label: {
                            Text(t("run.again")).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(DS.gold, in: Capsule())
                        }
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
                .padding(.bottom, 20)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .padding(16)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { heartBeat = true }
        }
    }

    // MARK: Flow

    private func currentDistance(_ date: Date) -> Double {
        distanceBase + (movingSince.map { date.timeIntervalSince($0) } ?? 0) * Self.speed
    }

    private func setMoving(_ on: Bool) {
        if on {
            if movingSince == nil { movingSince = Date() }
        } else if let since = movingSince {
            distanceBase += Date().timeIntervalSince(since) * Self.speed
            movingSince = nil
        }
    }

    /// Starts a run with the choices of the setup ("Again" keeps them).
    private func restart() {
        let pool = levelItems
        guard pool.count >= 4 else { return }
        let mine = poolItems
        let targets = usePool && !mine.isEmpty ? mine : pool
        boxes = boxCount(countChoices(targets.count))
        choosing = false
        questions = targets.shuffled().prefix(boxes).map { item in
            let others = pool.filter { $0.id != item.id }.shuffled().prefix(3)
            return RunQuestion(item: item, options: ([item] + others).shuffled())
        }
        index = 0
        score = 0
        streak = 0
        bestStreak = 0
        done = 0
        rightID = nil
        wrongID = nil
        lastWord = nil
        withAnimation { phase = .arriving }
        arrive()
    }

    private func arrive() {
        phase = .arriving
        boxGone = false
        boxX = 420
        setMoving(true)
        withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 1.0)) { boxX = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.25 : 1.05)) {
            guard phase == .arriving else { return }
            setMoving(false)
            phase = .waiting
        }
    }

    private func pick(_ option: WordPictureBank.Item) {
        guard phase == .waiting, questions.indices.contains(index) else { return }
        let item = questions[index].item
        A1Speaker.shared.say(option.full)
        withAnimation(.easeOut(duration: 0.2)) {
            lastWord = option
            lastRight = option.id == item.id
        }
        if option.id == item.id {
            AnswerSound.play(correct: true)
            streak += 1
            bestStreak = max(bestStreak, streak)
            let gained = 10 * streak
            score += gained
            gain = "+\(gained)"
            done += 1
            rightID = option.id
            phase = .jumping
            setMoving(true)
            if reduceMotion {
                boxGone = true
            } else {
                withAnimation(.easeOut(duration: 0.38)) { jump = CGSize(width: 70, height: -120) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                    withAnimation(.easeIn(duration: 0.36)) { jump = .zero }
                }
                withAnimation(.easeIn(duration: 0.75)) { boxGone = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                rightID = nil
                gain = ""
                if done >= boxes {
                    setMoving(false)
                    finish()
                } else {
                    index += 1
                    arrive()
                }
            }
        } else {
            AnswerSound.play(correct: false)
            streak = 0
            wrongID = option.id
            phase = .stumbling
            if !reduceMotion {
                shake = 0
                withAnimation(.linear(duration: 0.45)) { shake = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard phase == .stumbling else { return }
                wrongID = nil
                shake = 0
                phase = .waiting
            }
        }
    }

    private func finish() {
        BadgeStore.countGame()
        StreakStore.shared.record()
        StreakStore.shared.addXP(max(5, score / 10))
        withAnimation(.easeOut(duration: 0.3)) { phase = .finished }
    }
}

/// Three stars circling over Lina's head after a stumble.
private struct DizzyStars: View {
    @State private var turn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: i == 0 ? 16 : 12, weight: .bold))
                    .foregroundColor(i == 0 ? DS.gold : Color(red: 1, green: 0.88, blue: 0.54))
                    .shadow(color: .black.opacity(0.25), radius: 0, y: 1)
                    .offset(x: 24 * cos(Double(i) * 2.094), y: 9 * sin(Double(i) * 2.094))
            }
        }
        .rotationEffect(.degrees(turn ? 360 : 0))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { turn = true }
        }
        .accessibilityHidden(true)
    }
}

/// A short side-to-side shake of the scene after a wrong answer.
private struct RunShake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(amount * .pi * 6) * 7 * (1 - amount), y: 0))
    }
}

