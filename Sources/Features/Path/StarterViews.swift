import SwiftUI

/// Unit 0 of the A1 path: alphabet, sounds, numbers, greetings and a short test (Resources/content/starter_a1.json,
/// made by tools/starter.py). For learners who start from nothing.
struct StarterContent: Decodable {
    struct Letter: Decodable, Hashable {
        let letter: String
        let name: String
        let word: String
    }

    struct Sound: Decodable, Hashable {
        let spelling: String
        let say: LocText
        let examples: [String]
    }

    struct Phrase: Decodable, Hashable {
        let de: String
        let mean: LocText
    }

    let letters: [Letter]
    let sounds: [Sound]
    let greetings: [Phrase]

    static let shared: StarterContent? = Bundled.decode(StarterContent.self, "starter_a1")
}

/// Which parts of the start were opened (alphabet, sounds, numbers, greetings) and whether the test was passed.
enum StarterStore {
    static let parts = ["alphabet", "sounds", "numbers", "greetings", "test"]
    static let changed = Notification.Name("StarterChanged")
    private static let key = "starter.done"

    static func done() -> Set<String> { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }

    static func mark(_ part: String) {
        var all = done()
        guard !all.contains(part) else { return }
        all.insert(part)
        UserDefaults.standard.set(Array(all), forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }
}

/// The card at the top of the A1 path.
struct StarterCard: View {
    @State private var done = StarterStore.done()

    var body: some View {
        let count = StarterStore.parts.filter { done.contains($0) }.count
        HStack(spacing: 14) {
            Image(systemName: count == StarterStore.parts.count ? "checkmark" : "textformat.abc")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(count == StarterStore.parts.count ? .white : DS.onGold)
                .frame(width: 44, height: 44)
                .background(count == StarterStore.parts.count ? DS.success : DS.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(t("starter.title")).font(.system(size: 16, weight: .bold)).foregroundColor(DS.ink)
                Text(t("starter.progress", count)).font(.footnote).foregroundColor(DS.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onReceive(NotificationCenter.default.publisher(for: StarterStore.changed)) { _ in done = StarterStore.done() }
    }
}

struct StarterView: View {
    @EnvironmentObject private var model: A1Model
    @State private var done = StarterStore.done()

    var body: some View {
        List {
            Section {
                Text(t("starter.sub")).font(.subheadline).foregroundColor(DS.muted)
            }
            Section {
                row("alphabet", t("starter.alphabet"), "textformat.abc") { StarterAlphabetView() }
                row("sounds", t("starter.sounds"), "waveform") { StarterSoundsView() }
                row("numbers", t("starter.numbers"), "number") {
                    A1NumbersLearnView().onAppear { StarterStore.mark("numbers") }
                }
                row("greetings", t("starter.greetings"), "hand.wave.fill") { StarterGreetingsView() }
                row("test", t("starter.test"), "checkmark.seal.fill") {
                    A1QuizView(title: t("starter.test"), free: true, onFinish: { correct, total in
                        if total > 0 && correct * 100 / total >= 70 { StarterStore.mark("test") }
                    }) {
                        StarterQuiz.questions()
                    }
                }
            }
        }
        .navigationTitle(t("starter.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: StarterStore.changed)) { _ in done = StarterStore.done() }
    }

    private func row<Destination: View>(_ part: String, _ title: String, _ icon: String,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: done.contains(part) ? "checkmark.circle.fill" : icon)
                    .foregroundColor(done.contains(part) ? DS.success : DS.goldDeep)
            }
        }
    }
}

/// Every letter: tap to hear its German name and an example word.
struct StarterAlphabetView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("starter.alphabetNote")).font(.subheadline).foregroundColor(DS.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(StarterContent.shared?.letters ?? [], id: \.self) { item in
                        Button {
                            A1Speaker.shared.play([A1Line(s: -1, t: item.name), A1Line(s: -1, t: item.word)])
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.letter).font(.system(size: 28, weight: .heavy)).foregroundColor(DS.ink)
                                Text(item.name).font(.caption.weight(.semibold)).foregroundColor(DS.goldDeep)
                                Text(item.word).font(.caption2).foregroundColor(DS.muted).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84)
                            .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("\(item.letter), \(item.name), \(item.word)")
                    }
                }
            }
            .padding(DS.gutter)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("starter.alphabet"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { StarterStore.mark("alphabet") }
    }
}

/// Letters and letter groups that are read differently from how a Turkish or English speaker expects.
struct StarterSoundsView: View {
    var body: some View {
        List {
            Section {
                Text(t("starter.soundsNote")).font(.subheadline).foregroundColor(DS.muted)
            }
            ForEach(StarterContent.shared?.sounds ?? [], id: \.self) { sound in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(sound.spelling).font(.system(size: 22, weight: .heavy)).foregroundColor(DS.goldDeep)
                        Text(sound.say.text).font(.subheadline).foregroundColor(DS.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        ForEach(sound.examples, id: \.self) { word in
                            Button { A1Speaker.shared.say(word) } label: {
                                Label(word, systemImage: "speaker.wave.2.fill")
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(DS.chip, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(t("starter.sounds"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { StarterStore.mark("sounds") }
    }
}

struct StarterGreetingsView: View {
    var body: some View {
        List(StarterContent.shared?.greetings ?? [], id: \.self) { phrase in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(phrase.de).font(.system(size: 17, weight: .semibold))
                    Text(phrase.mean.text).font(.footnote).foregroundColor(DS.muted)
                }
                Spacer()
                A1SpeakButton(text: phrase.de)
            }
            .speaksOnTap(phrase.de)
        }
        .navigationTitle(t("starter.greetings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { StarterStore.mark("greetings") }
    }
}

/// The start test: which letter did you hear, which word did you hear (the special sounds), what does it mean.
enum StarterQuiz {
    static func questions() -> [A1Question] {
        guard let content = StarterContent.shared else { return [] }
        var out: [A1Question] = []
        let letters = content.letters
        for item in letters.shuffled().prefix(4) {
            let wrong = letters.filter { $0.letter != item.letter }.shuffled().prefix(3).map(\.letter)
            out.append(A1Question(id: "st-l-\(item.letter)", mode: .listen, kind: .choice, label: t("starter.alphabet"),
                                  prompt: t("starter.whichLetter"), speakFirst: item.name,
                                  options: ([item.letter] + wrong).shuffled(), answer: item.letter,
                                  explanation: "\(item.letter) = \(item.name) · \(item.word)"))
        }
        let words = content.sounds.flatMap { sound in sound.examples.map { ($0, sound) } }
        for (word, sound) in words.shuffled().prefix(5) {
            let wrong = words.filter { $0.1.spelling != sound.spelling }.map(\.0).shuffled().prefix(3)
            out.append(A1Question(id: "st-s-\(word)", mode: .listen, kind: .choice, label: t("starter.sounds"),
                                  prompt: t("q.listenWord"), speakFirst: word, options: ([word] + wrong).shuffled(),
                                  answer: word, explanation: "\(sound.spelling): \(sound.say.text)"))
        }
        for phrase in content.greetings.shuffled().prefix(4) {
            let wrong = content.greetings.filter { $0.de != phrase.de }.map(\.mean.text).shuffled().prefix(3)
            out.append(A1Question(id: "st-g-\(phrase.de)", mode: .wordToTr, kind: .choice, label: t("starter.greetings"),
                                  prompt: phrase.de, speakAfter: phrase.de, options: ([phrase.mean.text] + wrong).shuffled(),
                                  answer: phrase.mean.text, explanation: "\(phrase.de) = \(phrase.mean.text)"))
        }
        return out.shuffled()
    }
}
