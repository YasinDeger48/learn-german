import SwiftUI

/// One pair of the matching game: the German word and its meaning, or its picture.
struct MatchPair: Identifiable, Equatable {
    let id: String
    let art: String?        // der / die / das for nouns
    let word: String        // without the article
    let full: String        // what is spoken ("die Kerze")
    let meaning: String
    let picture: String?    // Resources/Covers name, picture mode only
}

enum MatchMode: String { case meaning, picture }

private enum MatchSide { case word, answer }

/// Word matching as a game for young and old (design: https://claude.ai/artifact/EqA2vZg3fVHXMn8KMNVnoi):
/// 5 rounds of 5 pairs, a German word with its meaning or its picture. Lina reacts to every move, right answers in a
/// row build a streak that multiplies the points, the end screen shows stars, the round's numbers, XP and new badges
/// (badge kind `match`). Bright colours in light and dark mode, rounded type, cards that press in like buttons.
struct MatchGameView: View {
    @EnvironmentObject private var model: A1Model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let theme: Int?

    private static let rounds = 5
    private static let pairsPerRound = 5

    private enum Mood { case start, pick, right, wrong }

    @State private var mode: MatchMode = .meaning
    @State private var round = 1
    @State private var pairs: [MatchPair] = []
    @State private var answers: [MatchPair] = []
    @State private var selection: (side: MatchSide, id: String)?
    @State private var done: Set<String> = []
    /// The card that was wrong, side and pair ("word-w12"): only that card flashes and shakes, not its partner.
    @State private var wrongKey: String?
    @State private var shakes: CGFloat = 0
    @State private var popID: String?
    @State private var gainID: String?
    @State private var gainText = ""
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var score = 0
    @State private var matches = 0
    @State private var errors = 0
    @State private var mood: Mood = .start
    @State private var moodTick = 0
    @State private var used: Set<String> = []
    @State private var startedAt = Date()
    @State private var result: MatchResult?
    @State private var pictureAvailable = false
    private let screenID = UUID()

    private static let ink = Color(red: 0.055, green: 0.059, blue: 0.047)
    private static let soft = Color(red: 0.42, green: 0.41, blue: 0.38)
    private static let edge = Color(red: 0.886, green: 0.863, blue: 0.784)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1, green: 0.953, blue: 0.769), Color(red: 0.992, green: 0.973, blue: 0.918),
                                    Color(red: 0.969, green: 0.969, blue: 0.957)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if let result {
                MatchResultView(result: result, finish: { dismiss() }, again: { newGame() })
                    .transition(.opacity)
            } else {
                game
            }
        }
        .environment(\.colorScheme, .light)
        .navigationTitle(t("practice.match"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            BadgeStore.shared.quizShown(screenID)
            if pairs.isEmpty {
                pictureAvailable = pool(.picture).count >= Self.pairsPerRound
                newGame()
            }
        }
        .onDisappear {
            A1Speaker.shared.stop()
            BadgeStore.shared.quizHidden(screenID)
        }
    }

    // MARK: Game screen

    private var game: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                linaRow
                progressBar
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 12) { ForEach(pairs) { wordCard($0) } }
                    VStack(spacing: 12) { ForEach(answers) { answerCard($0) } }
                }
                .padding(.top, 2)
                if pictureAvailable { modePicker.padding(.top, 8) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(1...Self.rounds, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.system(size: 19))
                        .foregroundColor(index < round ? DS.gold
                                         : index == round ? Color(red: 1, green: 0.88, blue: 0.54) : Color(white: 0.86))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(t("match.round", round, Self.rounds))
            Spacer()
            Text("\(score)")
                .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundColor(DS.gold)
                .padding(.horizontal, 14)
                .frame(minWidth: 58, minHeight: 36)
                .background(Self.ink, in: Capsule())
                .accessibilityLabel(t("games.score", score))
        }
        .padding(.top, 6)
    }

    private var linaRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            LinaAvatar(size: 86, mood: linaMood, variant: matches)
                .id(moodTick)  // a new face plays its little move again
            VStack(alignment: .leading, spacing: 2) {
                Text(linaLine.title).font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                Text(linaLine.sub).font(.system(size: 13, design: .rounded)).foregroundColor(Self.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                UnevenRoundedBubble()
                    .fill(Color.white)
                    .shadow(color: Self.edge, radius: 0, y: 3)
            )
            .padding(.bottom, 24)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .topTrailing) {
            if combo >= 2 {
                Text("x\(combo) " + t("match.streak"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 1, green: 0.48, blue: 0.27), in: Capsule())
                    .rotationEffect(.degrees(4))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: combo)
        .accessibilityElement(children: .combine)
    }

    private var progressBar: some View {
        HStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(red: 0.49, green: 0.84, blue: 0.61), DS.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, (proxy.size.width - 4) * CGFloat(done.count) / CGFloat(max(1, pairs.count))))
                        .padding(2)
                }
            }
            .frame(height: 12)
            .animation(.easeOut(duration: 0.35), value: done.count)
            Text("\(done.count)/\(pairs.count)")
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(Self.soft)
        }
    }

    private func wordCard(_ pair: MatchPair) -> some View {
        let state = cardState(.word, pair.id)
        return Button { tap(.word, pair) } label: {
            HStack(spacing: 8) {
                if let art = pair.art {
                    Text(art)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(minWidth: 34, minHeight: 26)
                        .background(a1ArticleColor(art), in: Capsule())
                }
                Text(pair.word)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(state == .done ? Color(red: 0.18, green: 0.48, blue: 0.30) : Self.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: mode == .picture ? 84 : 68)
        }
        .buttonStyle(CandyStyle(state: state))
        .disabled(state == .done)
        .modifier(MatchMotion(shake: wrongKey == Self.key(.word, pair.id) ? shakes : 0, pop: popID == pair.id, reduce: reduceMotion))
        .accessibilityLabel(pair.full)
        .accessibilityAddTraits(state == .selected ? .isSelected : [])
    }

    private func answerCard(_ pair: MatchPair) -> some View {
        let state = cardState(.answer, pair.id)
        return Button { tap(.answer, pair) } label: {
            ZStack {
                if mode == .picture, let name = pair.picture, let image = Covers.image(name) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .opacity(state == .done ? 0.55 : 1)
                } else {
                    Text(pair.meaning)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(state == .done ? Color(red: 0.18, green: 0.48, blue: 0.30) : Self.ink)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: mode == .picture ? 84 : 68)
            .overlay(alignment: .topTrailing) {
                if gainID == pair.id {
                    Text(gainText)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(Self.ink)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(DS.gold, in: Capsule())
                        .offset(x: -6, y: -12)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                }
            }
        }
        .buttonStyle(CandyStyle(state: state))
        .disabled(state == .done)
        .modifier(MatchMotion(shake: wrongKey == Self.key(.answer, pair.id) ? shakes : 0, pop: popID == pair.id, reduce: reduceMotion))
        .accessibilityLabel(mode == .picture ? t("match.picture", pair.meaning) : pair.meaning)
        .accessibilityAddTraits(state == .selected ? .isSelected : [])
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            modeButton(.meaning, t("match.mode.meaning"))
            modeButton(.picture, t("match.mode.picture"))
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Self.edge, lineWidth: 1.5))
    }

    private func modeButton(_ value: MatchMode, _ title: String) -> some View {
        Button {
            guard mode != value else { return }
            mode = value
            newGame()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(mode == value ? .white : Self.ink)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(mode == value ? Self.ink : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }

    // MARK: Lina

    private var linaMood: LinaMood {
        switch mood {
        case .start: return .calm
        case .pick: return .curious
        case .right: return .happy
        case .wrong: return .sad
        }
    }

    private var linaLine: (title: String, sub: String) {
        switch mood {
        case .start: return ("Los geht’s!", t("match.sub.start"))
        case .pick: return ("Was passt?", t(mode == .picture ? "match.sub.pickPicture" : "match.sub.pickMeaning"))
        case .right: return ("Super!", t(combo >= 3 ? "match.sub.streak" : "match.sub.right"))
        case .wrong: return ("Fast!", t("match.sub.wrong"))
        }
    }

    private func setMood(_ value: Mood) {
        mood = value
        moodTick += 1
    }

    // MARK: Moves

    private static func key(_ side: MatchSide, _ id: String) -> String { (side == .word ? "word-" : "answer-") + id }

    private func cardState(_ side: MatchSide, _ id: String) -> CandyStyle.State {
        if done.contains(id) { return .done }
        if wrongKey == Self.key(side, id) { return .wrong }
        if let selection, selection.side == side, selection.id == id { return .selected }
        return .normal
    }

    private func tap(_ side: MatchSide, _ pair: MatchPair) {
        guard !done.contains(pair.id) else { return }
        if side == .word { A1Speaker.shared.say(pair.full) }
        guard let current = selection, current.side != side else {
            selection = (side, pair.id)
            wrongKey = nil
            setMood(.pick)
            return
        }
        if current.id == pair.id {
            matched(pair)
        } else {
            missed(Self.key(side, pair.id))
        }
    }

    private func matched(_ pair: MatchPair) {
        if selection?.side == .answer { A1Speaker.shared.say(pair.full) }
        AnswerSound.play(correct: true)
        combo += 1
        bestCombo = max(bestCombo, combo)
        let gained = 10 * combo
        score += gained
        matches += 1
        selection = nil
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5)) {
            _ = done.insert(pair.id)
            popID = pair.id
            gainID = pair.id
            gainText = "+\(gained)"
        }
        setMood(.right)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if popID == pair.id { withAnimation { popID = nil } } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { if gainID == pair.id { withAnimation { gainID = nil } } }
        if done.count == pairs.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if round < Self.rounds {
                    round += 1
                    newRound()
                } else {
                    finish()
                }
            }
        }
    }

    private func missed(_ key: String) {
        AnswerSound.play(correct: false)
        errors += 1
        combo = 0
        wrongKey = key
        setMood(.wrong)
        if reduceMotion {
            shakes = 1
        } else {
            shakes = 0
            withAnimation(.linear(duration: 0.4)) { shakes = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if wrongKey == key {
                wrongKey = nil
                shakes = 0
            }
        }
    }

    // MARK: Rounds

    private func newGame() {
        round = 1
        score = 0
        combo = 0
        bestCombo = 0
        matches = 0
        errors = 0
        used = []
        startedAt = Date()
        withAnimation { result = nil }
        setMood(.start)
        newRound()
    }

    private func newRound() {
        var all = pool(mode).filter { !used.contains($0.id) }
        if all.count < Self.pairsPerRound {
            used = []
            all = pool(mode)
        }
        let picked = Array(all.shuffled().prefix(Self.pairsPerRound))
        used.formUnion(picked.map(\.id))
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            pairs = picked
            answers = picked.shuffled()
            done = []
            selection = nil
            wrongKey = nil
        }
    }

    private func finish() {
        let seconds = Int(Date().timeIntervalSince(startedAt))
        let xp = max(5, score / 10)
        StreakStore.shared.record()
        StreakStore.shared.addXP(xp)
        if errors == 0 {
            StreakStore.shared.addXP(XP.perfectBonus)
            StreakStore.shared.addPerfectRound()
        }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: BadgeStore.matchGamesKey) + 1, forKey: BadgeStore.matchGamesKey)
        BadgeStore.shared.refresh()
        let badges = BadgeStore.shared.takePending()
        let stars = errors == 0 ? 3 : (errors <= 3 ? 2 : 1)
        withAnimation(.easeOut(duration: 0.3)) {
            result = MatchResult(stars: stars, matches: matches, bestCombo: bestCombo, seconds: seconds,
                                 xp: xp + (errors == 0 ? XP.perfectBonus : 0), badges: badges)
        }
    }

    /// The words of the level (or of one theme). Picture mode: only words with a picture: A1 picture cards
    /// (wp-<level>-<id>), noun pictures of the unit word lists (wv-<slug>), for every level.
    private func pool(_ mode: MatchMode) -> [MatchPair] {
        let level = model.level.lowercased()
        var out: [MatchPair] = []
        var meanings = Set<String>()
        func add(_ pair: MatchPair) {
            guard !pair.meaning.isEmpty, meanings.insert(pair.meaning.lowercased()).inserted else { return }
            out.append(pair)
        }
        for word in model.content?.words ?? [] where theme == nil || word.theme == theme {
            let art = ["der", "die", "das"].contains(word.type) ? word.type : nil
            var picture: String?
            if mode == .picture {
                let card = "wp-\(level)-\(word.id)"
                let noun = art != nil ? Self.slug(word.de) : nil
                if Covers.exists(card) {
                    picture = card
                } else if let noun, Covers.exists(noun) {
                    picture = noun
                } else {
                    continue
                }
            }
            add(MatchPair(id: "w\(word.id)", art: art, word: word.de, full: word.withArticle, meaning: word.mean.text, picture: picture))
        }
        if mode == .picture && theme == nil {
            for unit in UnitBank.units(model.level) {
                for word in unit.vocab ?? [] {
                    guard let name = word.picture, Covers.exists(name) else { continue }
                    add(MatchPair(id: "v\(name)", art: word.art, word: word.de, full: word.full, meaning: word.meaning, picture: name))
                }
            }
        }
        return out
    }

    /// Same picture name rule as UnitWord.picture and tools/vocab_pictures.py.
    private static func slug(_ word: String) -> String {
        var s = word.lowercased()
        for (from, to) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] { s = s.replacingOccurrences(of: from, with: to) }
        return "wv-" + s.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }.joined(separator: "-")
    }
}

// MARK: - Result

struct MatchResult: Equatable {
    let stars: Int
    let matches: Int
    let bestCombo: Int
    let seconds: Int
    let xp: Int
    let badges: [Badge]
}

private struct MatchResultView: View {
    let result: MatchResult
    let finish: () -> Void
    let again: () -> Void
    @State private var shownStars = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let ink = Color(red: 0.055, green: 0.059, blue: 0.047)
    private static let soft = Color(red: 0.37, green: 0.37, blue: 0.34)
    private static let edge = Color(red: 0.91, green: 0.875, blue: 0.76)

    private var title: String { result.stars == 3 ? "Perfekt!" : (result.stars == 2 ? "Super gemacht!" : "Gut gemacht!") }
    private var note: String { t(result.stars == 3 ? "match.done.perfect" : (result.stars == 2 ? "match.done.good" : "match.done.ok")) }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: index == 1 ? 64 : 48))
                            .foregroundColor(index < result.stars ? DS.gold : Color(white: 0.85))
                            .padding(.bottom, index == 1 ? 12 : 0)
                            .scaleEffect(index < shownStars ? 1 : 0.2)
                            .opacity(index < shownStars ? 1 : 0)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(t("match.stars", result.stars))
                LinaAvatar(size: 130, mood: .happy)
                Text(title).font(.system(size: 36, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                Text(note).font(.system(size: 15, design: .rounded)).foregroundColor(Self.soft).multilineTextAlignment(.center)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile("\(result.matches)", t("match.stat.correct"), DS.das)
                    tile("x\(result.bestCombo)", t("match.stat.combo"), Color(red: 0.85, green: 0.33, blue: 0.16))
                    tile(String(format: "%d:%02d", result.seconds / 60, result.seconds % 60), t("match.stat.time"), DS.der)
                    tile("+\(result.xp)", t("match.stat.xp"), DS.gold, dark: true)
                }
                .padding(.top, 12)

                ForEach(result.badges) { badge in
                    HStack(spacing: 12) {
                        BadgeIcon(badge: badge, earned: true, size: 46)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t("match.newBadge")).font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.6)
                                .foregroundColor(DS.der)
                            Text(badge.title).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white).shadow(color: Self.edge, radius: 0, y: 4))
                }

                HStack(spacing: 10) {
                    Button(action: finish) {
                        Text(t("match.finish")).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Self.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Capsule().fill(Color.white).shadow(color: Self.edge, radius: 0, y: 4))
                    }
                    Button(action: again) {
                        Text(t("match.again")).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundColor(Self.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Capsule().fill(DS.gold).shadow(color: Color(red: 0.79, green: 0.60, blue: 0.12), radius: 0, y: 4))
                    }
                }
                .buttonStyle(.pressable)
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .overlay { if result.stars == 3 || !result.badges.isEmpty { ConfettiBurst().allowsHitTesting(false) } }
        .onAppear { showStars() }
    }

    private func tile(_ value: String, _ label: String, _ color: Color, dark: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded).monospacedDigit()).foregroundColor(color)
            Text(label).font(.system(size: 13, design: .rounded))
                .foregroundColor(dark ? Color(red: 0.81, green: 0.78, blue: 0.71) : Self.soft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(dark ? Self.ink : Color.white)
            .shadow(color: dark ? Color(red: 0.23, green: 0.23, blue: 0.21) : Self.edge, radius: 0, y: 4))
        .accessibilityElement(children: .combine)
    }

    private func showStars() {
        guard !reduceMotion else {
            shownStars = 3
            return
        }
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15 + Double(index) * 0.22) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { shownStars = index + 1 }
            }
        }
    }
}

// MARK: - Look

/// A card that sits on a darker edge and presses in when tapped, like a candy button.
private struct CandyStyle: ButtonStyle {
    enum State { case normal, selected, done, wrong }
    let state: State

    private var face: Color {
        switch state {
        case .normal: return .white
        case .selected: return Color(red: 1, green: 0.965, blue: 0.84)
        case .done: return Color(red: 0.867, green: 0.961, blue: 0.898)
        case .wrong: return Color(red: 1, green: 0.894, blue: 0.894)
        }
    }

    private var edge: Color {
        switch state {
        case .normal: return Color(red: 0.886, green: 0.863, blue: 0.784)
        case .selected: return Color(red: 0.85, green: 0.66, blue: 0.09)
        case .done: return Color(red: 0.725, green: 0.902, blue: 0.788)
        case .wrong: return Color(red: 0.90, green: 0.61, blue: 0.61)
        }
    }

    private var ring: Color? {
        switch state {
        case .selected: return DS.gold
        case .wrong: return Color(red: 0.94, green: 0.42, blue: 0.42)
        default: return nil
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        // Flat card with a thin border (owner: the 3D edge under the cards looked like a bad shadow).
        return configuration.label
            .frame(maxWidth: .infinity)
            .background(shape.fill(face))
            .overlay { shape.stroke(ring ?? edge, lineWidth: ring == nil ? 1.5 : 3) }
            .scaleEffect(pressed ? 0.97 : (state == .selected ? 1.03 : 1))
            .rotationEffect(.degrees(state == .selected ? -1 : 0))
            .opacity(state == .done ? 0.85 : 1)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: state)
    }
}

/// Shake on a wrong answer and a small jump on a right one.
private struct MatchMotion: ViewModifier {
    let shake: CGFloat
    let pop: Bool
    let reduce: Bool

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(progress: reduce ? 0 : shake))
            .scaleEffect(pop && !reduce ? 1.08 : 1)
    }
}

private struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let fade = 1 - progress
        let x = sin(progress * .pi * 6) * 8 * fade
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

/// Lina's speech bubble: round corners with a small sharp one pointing at her.
private struct UnevenRoundedBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let small: CGFloat = 6
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + small, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - small), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
