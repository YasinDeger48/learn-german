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
        AnswerSound.play(correct: ok)
        if !ok { A1Speaker.shared.say(word.withArticle) }
        current = (current + 1) % nouns.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { flash = nil }
    }
}

/// Word matching (route .match): the game in MatchGameView.swift.
struct A1MatchView: View {
    let theme: Int?

    var body: some View { MatchGameView(theme: theme) }
}
