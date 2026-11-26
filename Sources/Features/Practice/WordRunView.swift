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
    private static let boxes = 10
    private static let speed: Double = 170          // points per second on the near layer

    @State private var questions: [RunQuestion] = []
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

    private static let ink = Color(red: 0.055, green: 0.059, blue: 0.047)
    private static let soft = Color(red: 0.42, green: 0.41, blue: 0.38)

    var body: some View {
        ZStack {
            Color(red: 0.992, green: 0.973, blue: 0.918).ignoresSafeArea()
            if questions.isEmpty {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    scene.frame(height: 400)
                    answers
                }
            }
            if phase == .finished { finishView.transition(.opacity) }
        }
        .environment(\.colorScheme, .light)
        .navigationTitle(t("run.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: start)
        .onDisappear { A1Speaker.shared.stop() }
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

    private var hud: some View {
        HStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.9))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(red: 0.49, green: 0.84, blue: 0.61), DS.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, (proxy.size.width - 6) * CGFloat(done) / CGFloat(Self.boxes)))
                        .padding(3)
                }
            }
            .frame(height: 16)
            .overlay(alignment: .trailing) {
                Image(systemName: "flag.checkered").font(.system(size: 14, weight: .bold)).foregroundColor(Self.ink).offset(x: 4, y: -12)
            }
            .animation(.easeOut(duration: 0.4), value: done)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(t("run.boxes", done, Self.boxes))
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 12, weight: .bold))
                Text("\(score)").font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
            }
            .foregroundColor(DS.gold)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Self.ink, in: Capsule())
        }
        .padding(.horizontal, 16)
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
            }
            Spacer(minLength: 0)
        }
        .padding(16)
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
                    Text(t("run.finishSub", Self.boxes, score, max(1, bestStreak)))
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

    private func start() {
        guard questions.isEmpty else { return }
        restart()
    }

    private func restart() {
        let pool = WordPictureBank.items(level: model.level, content: model.content)
        guard pool.count >= 4 else { return }
        questions = pool.shuffled().prefix(Self.boxes).map { item in
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
                if done >= Self.boxes {
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

/// The card under the "keep going" tiles on Today.
struct WordRunCard: View {
    var body: some View {
        ZStack(alignment: .leading) {
            if let far = RunArt.far {
                Image(uiImage: far).resizable().scaledToFill()
                    .frame(height: 120)
                    .clipped()
            }
            LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0)], startPoint: .leading, endPoint: .trailing)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("run.badge")).font(.system(size: 11, weight: .heavy)).tracking(1.6).foregroundColor(DS.gold)
                    Text(t("run.title")).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(.white)
                    Text(t("run.cardSub")).font(.footnote).foregroundColor(.white.opacity(0.9))
                }
                .padding(.leading, 16)
                Spacer(minLength: 0)
                if let lina = RunArt.run.first {
                    Image(uiImage: lina).resizable().scaledToFit().frame(width: 118, height: 118).offset(y: 6)
                }
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("run.title"))
        .accessibilityHint(t("run.cardSub"))
    }
}
