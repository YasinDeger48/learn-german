import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Lina AI (Apple's on-device model, Foundation Models framework)
// Only on iOS 26+ with Apple Intelligence: `LinaAI.isAvailable` hides every AI button elsewhere. Runs on the phone,
// offline and free. The rest of the app never sees a FoundationModels type: everything goes through this file.
// Design: https://claude.ai/artifact/BTCHF23AfJ8LFkq5DTBGAE

/// One fix in Lina's review of a written text.
struct LinaFix: Hashable {
    let wrong: String
    let right: String
    let why: String
}

/// Lina's review of a written text (writing tasks).
struct LinaReview: Hashable {
    let praise: String
    let fixes: [LinaFix]
    let tip: String
}

/// Lina's help for a score (TaskScorer): which points the text covers in other words, and the language (0–4).
struct LinaRating: Hashable {
    let covered: Set<Int>
    let language: Int
}

enum LinaAI {
    /// The model can be used now (iOS 26+, Apple Intelligence on and downloaded).
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    /// What Apple says about the model on this phone, for Settings (why Lina chat is hidden).
    static var statusText: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // `if case` instead of a switch: Apple may add new reasons.
            let availability = SystemLanguageModel.default.availability
            if case .available = availability { return t("ai.status.ready") }
            if case .unavailable(.deviceNotEligible) = availability { return t("ai.status.device") }
            if case .unavailable(.appleIntelligenceNotEnabled) = availability { return t("ai.status.off") }
            if case .unavailable(.modelNotReady) = availability { return t("ai.status.loading") }
            return t("ai.status.other")
        }
        return t("ai.status.ios")
        #else
        return t("ai.status.ios")
        #endif
    }

    private static let languageNames = ["tr": "Turkish", "en": "English", "es": "Spanish", "fr": "French",
                                        "it": "Italian", "ku": "Kurmanji Kurdish (Latin script)", "ar": "Arabic"]

    /// The language Lina explains in: the learner's language when the model knows it, else English.
    static var explainLanguage: String {
        let code = Localizer.shared.language.rawValue
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let known = SystemLanguageModel.default.supportedLanguages.contains { $0.languageCode?.identifier == code }
            return known ? (languageNames[code] ?? "English") : "English"
        }
        #endif
        return languageNames[code] ?? "English"
    }

    private static var teacher: String {
        "You are Lina, the friendly mascot and German teacher of the Deschly app. You explain German to learners kindly "
            + "and very briefly. Write the explanation in \(explainLanguage); German words and sentences stay German. "
            + "No markdown, no headings, no lists with symbols."
    }

    /// "Lina, neden?": why the learner's answer is wrong, with one example. `again` asks for another example.
    static func explainMistake(question: String, given: String, answer: String, rule: String?, level: String,
                               again: Bool) async -> String? {
        var prompt = "Level \(level). Exercise: \(question)\nThe learner answered: \(given.isEmpty ? "(nothing)" : given)\n"
            + "The correct answer is: \(answer)\n"
        if let rule, !rule.isEmpty { prompt += "The grammar rule of this topic: \(rule)\n" }
        prompt += again
            ? "Give one more, different short German example sentence for the same rule and its translation. Two lines at most."
            : "In at most 3 short sentences, say why the learner's answer is wrong and why the correct answer is right. "
                + "Then one short German example sentence with its translation."
        return await respond(instructions: teacher, prompt: prompt)
    }

    /// "Lina değerlendirsin": praise, up to three fixes and one tip for a short German text.
    static func reviewWriting(task: String, points: [String], text: String, level: String) async -> LinaReview? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAvailable {
            let prompt = "Level \(level). Writing task: \(task)\nPoints the text should cover: \(points.joined(separator: "; "))\n"
                + "The learner's text:\n\(text)\n\nReview it for this level. Only real mistakes count as fixes (at most 3); "
                + "\"wrong\" is the part exactly as the learner wrote it."
            do {
                let session = LanguageModelSession(instructions: teacher)
                let result = try await session.respond(to: prompt, generating: GenReview.self).content
                return LinaReview(praise: result.praise,
                                  fixes: result.fixes.prefix(3).map { LinaFix(wrong: $0.wrong, right: $0.right, why: $0.why) },
                                  tip: result.tip)
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// Scoring help for a written or spoken answer: the points it covers (also in other words) and the language
    /// for the level, 0 (very poor) to 4 (very good). Spoken answers come from speech recognition.
    static func rate(task: String, points: [String], text: String, level: String, spoken: Bool) async -> LinaRating? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAvailable {
            let numbered = points.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "\n")
            let prompt = "Level \(level). Task: \(task)\nPoints (number: point):\n\(numbered)\n\n"
                + (spoken ? "What the learner said (speech recognition, no punctuation):\n" : "The learner's text:\n")
                + text + "\n\nList the numbers of the points the answer really covers, also when said in other words. "
                + "Rate the German for this level from 0 (very poor, hard to understand) to 4 (very good, few mistakes)."
                + (spoken ? " Ignore punctuation and capital letters." : "")
            do {
                let session = LanguageModelSession(instructions: teacher)
                let result = try await session.respond(to: prompt, generating: GenRating.self).content
                let covered = Set(result.coveredPoints.filter { points.indices.contains($0) })
                return LinaRating(covered: covered, language: min(4, max(0, result.language)))
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// One question, one answer (no memory).
    static func respond(instructions: String, prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAvailable {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let text = try await session.respond(to: prompt).content.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

// MARK: - Conversations (chat role play, questions about a text)

/// One message of a conversation with Lina. For the learner's messages Lina may add a correction (a real mistake:
/// the corrected sentence and why) or an alternative (correct, but this is more natural).
struct LinaMessage: Identifiable, Equatable {
    let id = UUID()
    let fromLina: Bool
    let text: String
    var translation: String = ""
    var correction: String = ""
    var why: String = ""
    var alternative: String = ""
}

/// A conversation with memory (the model keeps the transcript). `corrects`: role play, where Lina also checks the
/// learner's German and translates her own replies; otherwise Lina simply answers (questions about a text).
@MainActor
final class LinaChat: ObservableObject {
    @Published private(set) var messages: [LinaMessage] = []
    @Published private(set) var busy = false
    @Published private(set) var failed = false

    let corrects: Bool
    private let instructions: String
    private let opening: String?
    /// A LanguageModelSession (kept as AnyObject: the type exists only on iOS 26+).
    private var session: AnyObject?

    /// `opening`: what Lina is asked to start with (nil = the learner writes first).
    init(instructions: String, corrects: Bool, opening: String?) {
        self.instructions = instructions
        self.corrects = corrects
        self.opening = opening
    }

    /// Role play in a scene, at the learner's level.
    static func rolePlay(scene: String, role: String, level: String) -> LinaChat {
        let language = LinaAI.explainLanguage
        let instructions = "You are Lina, the friendly mascot of the Deschly German app, in a role play with a learner. "
            + "Scene: \(scene). You play: \(role). The learner's CEFR level is \(level). "
            + "Always answer in simple, natural German suited to that level: 1 to 3 short sentences, and usually end with a "
            + "short question so the conversation goes on. Stay in the scene. "
            + "Put the \(language) translation of your German reply in \"translation\". "
            + "Also check the learner's last message: if it has a real mistake, put the whole corrected sentence in "
            + "\"correction\" and a very short reason in \(language) in \"why\"; if it is correct but a more natural "
            + "phrase exists, put that phrase in \"alternative\". Leave a field empty when there is nothing to say. "
            + "Never praise or correct inside the German reply itself."
        return LinaChat(instructions: instructions, corrects: true,
                        opening: "Start the conversation: greet the learner in the scene in one or two short German sentences.")
    }

    /// Questions about a text the learner is reading.
    static func aboutText(title: String, text: String, level: String) -> LinaChat {
        let instructions = "You are Lina, the friendly German teacher of the Deschly app. The learner (level \(level)) is reading "
            + "this German text titled \"\(title)\":\n\(text)\n\nAnswer the learner's questions about the text, its words "
            + "and its grammar briefly and kindly, in \(LinaAI.explainLanguage); German words and sentences stay German. "
            + "No markdown, no headings."
        return LinaChat(instructions: instructions, corrects: false, opening: nil)
    }

    func start() {
        guard messages.isEmpty, let opening else { return }
        ask(opening, shown: nil)
    }

    func send(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !busy else { return }
        ask(clean, shown: LinaMessage(fromLina: false, text: clean))
    }

    /// Asks the model; the learner's message (if any) is shown at once and gets Lina's correction afterwards.
    private func ask(_ prompt: String, shown: LinaMessage?) {
        if let shown { messages.append(shown) }
        let mine = shown.map { _ in messages.count - 1 }
        busy = true
        failed = false
        Task {
            let reply = await reply(to: prompt)
            busy = false
            guard let reply else {
                failed = true
                return
            }
            if let mine, messages.indices.contains(mine) {
                messages[mine].correction = reply.correction
                messages[mine].why = reply.why
                messages[mine].alternative = reply.alternative
            }
            messages.append(LinaMessage(fromLina: true, text: reply.text, translation: reply.translation))
        }
    }

    private struct Reply {
        var text = ""
        var translation = ""
        var correction = ""
        var why = ""
        var alternative = ""
    }

    private func reply(to prompt: String) async -> Reply? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), LinaAI.isAvailable {
            let live: LanguageModelSession
            if let existing = session as? LanguageModelSession {
                live = existing
            } else {
                live = LanguageModelSession(instructions: instructions)
                session = live
            }
            do {
                if corrects {
                    let turn = try await live.respond(to: prompt, generating: GenChatTurn.self).content
                    return Reply(text: turn.reply, translation: turn.translation, correction: Self.clean(turn.correction),
                                 why: Self.clean(turn.why), alternative: Self.clean(turn.alternative))
                } else {
                    let text = try await live.respond(to: prompt).content.trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? nil : Reply(text: text)
                }
            } catch {
                session = nil  // e.g. the context is full: the next message starts a fresh session
                return nil
            }
        }
        #endif
        return nil
    }

    /// The model sometimes writes "none" or "-" instead of leaving a field empty.
    private static func clean(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["", "-", "—", "none", "n/a", "null", "keine", "yok"].contains(trimmed.lowercased()) ? "" : trimmed
    }
}

// MARK: - Structured answers (guided generation)

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GenChatTurn {
    @Guide(description: "Lina's reply in simple German, 1 to 3 short sentences")
    var reply: String
    @Guide(description: "Translation of the German reply into the learner's language")
    var translation: String
    @Guide(description: "The learner's last message fully corrected, only if it had a real mistake, else empty")
    var correction: String
    @Guide(description: "Very short reason for the correction in the learner's language, else empty")
    var why: String
    @Guide(description: "A more natural German way to say the learner's correct message, else empty")
    var alternative: String
}

@available(iOS 26.0, *)
@Generable
struct GenFix {
    @Guide(description: "The wrong part exactly as the learner wrote it")
    var wrong: String
    @Guide(description: "The corrected German")
    var right: String
    @Guide(description: "Very short reason in the learner's language")
    var why: String
}

@available(iOS 26.0, *)
@Generable
struct GenRating {
    @Guide(description: "Numbers of the points the answer really covers")
    var coveredPoints: [Int]
    @Guide(description: "Language for the level: 0 very poor, 1 poor, 2 fair, 3 good, 4 very good")
    var language: Int
}

@available(iOS 26.0, *)
@Generable
struct GenReview {
    @Guide(description: "One sentence of praise in the learner's language")
    var praise: String
    @Guide(description: "Up to three fixes of real mistakes")
    var fixes: [GenFix]
    @Guide(description: "One short tip in the learner's language to make the text better")
    var tip: String
}
#endif
