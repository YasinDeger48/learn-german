import SwiftUI
import UIKit

/// One line of a writing or speaking score, shown in "Why this score".
struct ScoreCriterion: Identifiable {
    /// "content", "form", "language", "fluency", "pronunciation".
    let id: String
    /// 0…1.
    let earned: Double
    let weight: Double
    var notes: [String] = []

    var titleKey: String { "score.\(id)" }
}

/// A score made of criteria, like the Goethe exams (task done, form, language…).
struct TaskScore {
    var criteria: [ScoreCriterion]
    /// Set when Lina (Apple's on-device model) took part.
    var byLina = false

    var percent: Int {
        let weight = criteria.map(\.weight).reduce(0, +)
        guard weight > 0 else { return 0 }
        return Int((criteria.map { $0.earned * $0.weight }.reduce(0, +) / weight * 100).rounded())
    }
}

/// Rules that work on every phone without the internet; Lina (LinaAI.rate) may add points the learner made in other
/// words and a judgement of the language. The content can only go up through Lina, never down; her language
/// judgement can move the rule judgement by at most a quarter.
enum TaskScorer {
    /// Linking words that show a text with real sentences (B1 and above).
    private static let connectors: Set<String> = [
        "weil", "dass", "denn", "deshalb", "deswegen", "darum", "aber", "sondern", "obwohl", "wenn", "falls", "damit",
        "trotzdem", "außerdem", "ob", "während", "bevor", "nachdem", "zuerst", "danach", "schließlich", "jedoch",
        "allerdings", "daher", "einerseits", "andererseits",
    ]
    /// The same words as SpeechScore keys ("außerdem" → "ausserdem", "während" → "wahrend").
    private static let connectorKeys = Set(connectors.map { SpeechScore.key($0) })

    static func levelRank(_ level: String) -> Int { ["A1", "A2", "B1", "B2"].firstIndex(of: level.uppercased()) ?? 0 }

    // MARK: Writing

    static func writing(_ task: WritingTask, text: String, rating: LinaRating? = nil) -> TaskScore {
        let words = SpeechScore.split(text)
        let minWords = task.minWords ?? 25
        let points = task.points ?? []

        var covered = 0
        var contentNotes: [String] = []
        for (index, point) in points.enumerated() {
            if SpeechScore.mentions(text, point.keys) {
                covered += 1
            } else if rating?.covered.contains(index) == true {
                covered += 1
                contentNotes.append(t("score.linaPoint", point.label.text))
            } else {
                contentNotes.append(t("score.missingPoint", point.label.text))
            }
        }
        var content = points.isEmpty ? 1 : Double(covered) / Double(points.count)
        // Key phrases alone are no text: a text under half the length counts less.
        let share = min(1, Double(words.count) / Double(max(1, minWords)))
        if share < 0.5 {
            content *= share * 2
            contentNotes.append(t("score.tooShort", minWords))
        }

        var checks: [(ok: Bool, label: String)] = []
        if task.kind != "forum" {
            checks.append((SpeechScore.mentions(text, WritingBank.greeting), t("write.greeting")))
            checks.append((SpeechScore.mentions(text, WritingBank.closing), t("write.closing")))
        }
        checks.append((words.count >= minWords, t("write.length", minWords)))
        if task.formal == true { checks.append((usesSie(text), t("score.formalSie"))) }
        if levelRank(task.level) >= 2 { checks.append((connectorCount(text) >= 2, t("score.connectorsNeeded"))) }
        let form = Double(checks.filter { $0.ok }.count) / Double(max(1, checks.count))

        var criteria = [
            ScoreCriterion(id: "content", earned: content, weight: 0.5, notes: contentNotes),
            ScoreCriterion(id: "form", earned: form, weight: 0.25,
                           notes: checks.filter { !$0.ok }.map { t("score.missingForm", $0.label) }),
        ]
        if let language = language(text, ai: rating?.language) { criteria.append(language) }
        return TaskScore(criteria: criteria, byLina: rating != nil)
    }

    /// A formal text says "Sie" and never "du" / "dich" / "dir".
    private static func usesSie(_ text: String) -> Bool {
        let words = SpeechScore.split(text).map { $0.trimmingCharacters(in: .punctuationCharacters) }
        let polite = words.contains { ["Sie", "Ihnen", "Ihr", "Ihre", "Ihren", "Ihrem", "Ihrer"].contains($0) }
        let familiar = words.contains { ["du", "dich", "dir", "dein", "deine", "deinen", "deinem"].contains($0.lowercased()) }
        return polite && !familiar
    }

    private static func connectorCount(_ text: String) -> Int {
        SpeechScore.split(text).filter { connectorKeys.contains(SpeechScore.key($0)) }.count
    }

    /// Spelling with the iPhone's German dictionary (UITextChecker), errors per word in bands; Lina's 0–4 judgement
    /// moves it by at most a quarter. Nil when the phone has no German dictionary and Lina did not judge.
    private static func language(_ text: String, ai: Int?) -> ScoreCriterion? {
        var notes: [String] = []
        var rule: Double?
        if let counted = spelling(text), counted.words > 0 {
            let errors = counted.errors
            let rate = Double(errors) / Double(counted.words)
            rule = rate <= 0.03 ? 1 : rate <= 0.07 ? 0.75 : rate <= 0.12 ? 0.5 : rate <= 0.2 ? 0.25 : 0
            if errors > 0 { notes.append(t("score.spelling", errors)) }
        }
        let lina = ai.map { Double(min(4, max(0, $0))) / 4 }
        let earned: Double
        switch (rule, lina) {
        case let (rule?, lina?): earned = (rule + min(rule + 0.25, max(rule - 0.25, lina))) / 2
        case let (rule?, nil): earned = rule
        case let (nil, lina?): earned = lina
        case (nil, nil): return nil
        }
        return ScoreCriterion(id: "language", earned: earned, weight: 0.25, notes: notes)
    }

    /// Misspelled words and all words, or nil without a German dictionary on the phone.
    static func spelling(_ text: String) -> (errors: Int, words: Int)? {
        guard let language = UITextChecker.availableLanguages.first(where: { $0 == "de_DE" })
                ?? UITextChecker.availableLanguages.first(where: { $0.hasPrefix("de") }) else { return nil }
        let checker = UITextChecker()
        let length = (text as NSString).length
        var errors = 0
        var offset = 0
        while offset < length {
            let range = checker.rangeOfMisspelledWord(in: text, range: NSRange(location: 0, length: length),
                                                      startingAt: offset, wrap: false, language: language)
            if range.location == NSNotFound { break }
            errors += 1
            offset = range.location + max(1, range.length)
        }
        return (errors, SpeechScore.split(text).count)
    }

    // MARK: Speaking

    /// Speaking task: points covered, words per minute (fluency), words the recogniser was unsure of
    /// (a rough sign of pronunciation) and, with Lina, the language.
    static func speaking(_ task: SpeakingTask, heard: String, seconds: Int, unsure: Set<String>,
                         rating: LinaRating? = nil) -> TaskScore {
        let words = SpeechScore.split(heard)
        var covered = 0
        var contentNotes: [String] = []
        for (index, point) in task.points.enumerated() {
            if SpeechScore.mentions(heard, point.keys) {
                covered += 1
            } else if rating?.covered.contains(index) == true {
                covered += 1
                contentNotes.append(t("score.linaPoint", point.label.text))
            } else {
                contentNotes.append(t("score.missingPoint", point.label.text))
            }
        }
        let content = words.count < 5 || task.points.isEmpty ? 0 : Double(covered) / Double(task.points.count)

        // Learners at A1 speak slowly; the bands rise with the level.
        let perMinute = Double(words.count) / Double(max(10, seconds)) * 60
        let base = [35.0, 45, 60, 75][levelRank(task.level)]
        let fluency = perMinute >= base ? 1 : perMinute >= base * 0.7 ? 0.66 : perMinute >= base * 0.45 ? 0.33 : 0

        let unsureShare = words.isEmpty ? 1 : Double(words.filter { unsure.contains(SpeechScore.key($0)) }.count) / Double(words.count)
        let clear = unsureShare <= 0.1 ? 1 : unsureShare <= 0.25 ? 0.66 : unsureShare <= 0.4 ? 0.33 : 0

        var criteria = [
            ScoreCriterion(id: "content", earned: content, weight: 0.5, notes: contentNotes),
            ScoreCriterion(id: "fluency", earned: words.count < 5 ? 0 : fluency, weight: 0.2,
                           notes: [t("score.perMinute", Int(perMinute.rounded()))]),
            ScoreCriterion(id: "pronunciation", earned: words.count < 5 ? 0 : clear, weight: 0.15,
                           notes: unsureShare > 0.1 ? [t("score.unclear")] : []),
        ]
        if let language = rating?.language {
            criteria.append(ScoreCriterion(id: "language", earned: Double(min(4, max(0, language))) / 4, weight: 0.15))
        }
        return TaskScore(criteria: criteria, byLina: rating != nil)
    }
}

/// "Why this score": one bar per criterion with what was missing.
struct ScoreBreakdownView: View {
    let score: TaskScore
    var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("score.why")).font(.system(size: 17, weight: .bold)).foregroundColor(DS.ink)
                Spacer()
                Text("\(score.percent)%").font(.system(size: 17, weight: .heavy).monospacedDigit())
                    .foregroundColor(score.percent >= 60 ? DS.success : DS.ink)
            }
            ForEach(score.criteria) { criterion in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(t(criterion.titleKey)).font(.subheadline.weight(.semibold)).foregroundColor(DS.ink)
                        Spacer()
                        Text("\(Int((criterion.earned * 100).rounded()))%").font(.subheadline.monospacedDigit()).foregroundColor(DS.muted)
                    }
                    ProgressView(value: criterion.earned).tint(criterion.earned >= 0.6 ? DS.success : DS.gold)
                    ForEach(criterion.notes, id: \.self) { note in
                        Text(note).font(.caption).foregroundColor(DS.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if busy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(t("score.linaBusy")).font(.caption).foregroundColor(DS.muted)
                }
            } else if score.byLina {
                Label(t("score.linaNote"), systemImage: "sparkles").font(.caption).foregroundColor(DS.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(t("score.estimate")).font(.caption2).foregroundColor(DS.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
