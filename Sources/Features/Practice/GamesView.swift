import SwiftUI
import Combine

// MARK: - Games

struct A1SprintView: View {
    @EnvironmentObject private var model: A1Model
    @State private var nouns: [A1Word] = []
    @State private var current = 0
    @State private var score = 0
    @State private var remaining = 60
    @State private var running = false
    @State private var finished = false
    @State private var flash: Color?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Label(t("games.seconds", remaining), systemImage: "timer").font(.title3.monospacedDigit())
                Spacer()
                Text(t("games.score", score)).font(.title3.bold().monospacedDigit())
            }
            Spacer()
            if running, current < nouns.count {
                let word = nouns[current]
                VStack(spacing: 8) {
                    Text(word.de).font(.system(size: 40, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1)
                    Text(word.mean.text).foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background((flash ?? Color.clear).opacity(0.25), in: RoundedRectangle(cornerRadius: 20))
                HStack(spacing: 12) {
                    ForEach(["der", "die", "das"], id: \.self) { article in
                        Button {
                            answer(article)
                        } label: {
                            Text(article).font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(a1ArticleColor(article))
                        .foregroundStyle(Color.white)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text(finished ? t("games.timeUp", score) : t("games.sprintIntro"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(t("games.record", model.state.bestSprint)).foregroundStyle(.secondary)
                    Text(t("games.rules")).font(.footnote).foregroundStyle(.secondary)
                    Button(finished ? t("games.again") : t("games.start"), action: start)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            Spacer()
        }
        .padding(20)
        .navigationTitle(t("practice.sprint"))
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            guard running else { return }
            remaining -= 1
            if remaining <= 0 {
                running = false
                finished = true
                model.saveSprint(score)
            }
        }
    }

    private func start() {
        guard let words = model.content?.words else { return }
        nouns = words.filter(\.isNoun).shuffled()
        current = 0
        score = 0
        remaining = 60
        finished = false
        running = true
    }

    private func answer(_ article: String) {
        let word = nouns[current]
        let ok = word.type == article
        score = max(0, score + (ok ? 1 : -1))
        flash = ok ? .green : .red
        if !ok { A1Speaker.shared.say(word.withArticle) }
        current = (current + 1) % nouns.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { flash = nil }
    }
}

struct A1MatchView: View {
    @EnvironmentObject private var model: A1Model
    let theme: Int?
    @State private var pairs: [A1Word] = []
    @State private var right: [A1Word] = []
    @State private var selectedLeft: Int?
    @State private var done: Set<Int> = []
    @State private var wrongFlash: Int?
    @State private var rounds = 0
    @State private var errors = 0

    var body: some View {
        VStack(spacing: 16) {
            Text(t("games.matchHint")).font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) {
                    ForEach(pairs) { word in
                        tile(word.withArticle, active: selectedLeft == word.id, gone: done.contains(word.id), color: a1ArticleColor(word.type)) {
                            selectedLeft = word.id
                            A1Speaker.shared.say(word.withArticle)
                        }
                    }
                }
                VStack(spacing: 10) {
                    ForEach(right) { word in
                        tile(word.mean.text, active: wrongFlash == word.id, gone: done.contains(word.id), color: .primary) {
                            match(word)
                        }
                    }
                }
            }
            Text(t("games.matchStats", rounds, errors)).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .navigationTitle(t("practice.match"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if pairs.isEmpty { newRound() } }
    }

    private func tile(_ text: String, active: Bool, gone: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, 6)
                .background(active ? a1Accent.opacity(0.3) : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .opacity(gone ? 0.15 : 1)
        .disabled(gone)
    }

    private func match(_ word: A1Word) {
        guard let left = selectedLeft else { return }
        if left == word.id {
            done.insert(word.id)
            selectedLeft = nil
            if done.count == pairs.count {
                rounds += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { newRound() }
            }
        } else {
            errors += 1
            wrongFlash = word.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { wrongFlash = nil }
        }
    }

    private func newRound() {
        guard let words = model.content?.words else { return }
        let pool = words.filter { theme == nil || $0.theme == theme }
        var seenMeanings: Set<String> = []
        var picked: [A1Word] = []
        for word in pool.shuffled() where !seenMeanings.contains(word.mean.text) {
            seenMeanings.insert(word.mean.text)
            picked.append(word)
            if picked.count == 5 { break }
        }
        pairs = picked
        right = picked.shuffled()
        done = []
        selectedLeft = nil
    }
}
