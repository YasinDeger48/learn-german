import Foundation

/// Builds the quiz for a daily text: the comprehension questions from the content file
/// plus questions made from the text itself (word meaning, gap fill, sentence order, dictation).
enum ReadingQuiz {
    static func sentences(of text: DailyText) -> [String] { text.paragraphs.flatMap(sentences(in:)) }

    /// One paragraph cut after . ! ? followed by a space (tools/word_audio.py split_sentences does the same, so the
    /// recorded sentences are found).
    static func sentences(in paragraph: String) -> [String] {
        var result: [String] = []
        var current = ""
        let chars = Array(paragraph)
        for (i, ch) in chars.enumerated() {
            current.append(ch)
            let atEnd = i == chars.count - 1
            let nextIsSpace = !atEnd && chars[i + 1] == " "
            if (ch == "." || ch == "!" || ch == "?") && (atEnd || nextIsSpace) {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { result.append(rest) }
        return result
    }

    static func questions(for text: DailyText, words: [A1Word]) -> [A1Question] {
        var out: [A1Question] = []
        let label = text.title
        let context = text.paragraphs.joined(separator: "\n\n")
        let id = { (n: String) in "dq-\(text.id)-\(n)" }

        // 1. Comprehension from the file (multiple choice and Richtig / Falsch).
        for (index, item) in text.questions.prefix(5).enumerated() {
            if item.type == "tf" {
                let answer = item.answer == 0 ? "Richtig" : "Falsch"
                out.append(A1Question(id: id("q\(index)"), mode: .reading, kind: .choice, label: label, prompt: item.q,
                                      detail: t("reading.trueFalse"), context: context,
                                      options: ["Richtig", "Falsch"], answer: answer))
            } else if let options = item.options, item.answer >= 0, item.answer < options.count {
                out.append(A1Question(id: id("q\(index)"), mode: .reading, kind: .choice, label: label, prompt: item.q,
                                      context: context, options: options.shuffled(), answer: options[item.answer]))
            }
        }

        let glossary = text.glossary
        // 2. Meaning of a word from the text.
        if let gloss = glossary.first, glossary.count >= 4 {
            let correct = gloss.mean.text
            let wrong = Array(glossary.dropFirst().map { $0.mean.text }.filter { $0 != correct }.shuffled().prefix(3))
            if wrong.count == 3 {
                out.append(A1Question(id: id("m0"), mode: .wordToTr, kind: .choice, label: label, prompt: gloss.display,
                                      detail: t("reading.meaning"), speakAfter: gloss.display,
                                      options: ([correct] + wrong).shuffled(), answer: correct,
                                      explanation: "\(gloss.display) = \(correct)"))
            }
        }

        // 3. Gap fill: blank a glossary word in its sentence.
        let allSentences = sentences(of: text)
        let nounPool = words.filter { $0.isNoun && !$0.de.contains(" ") }.map(\.de)
        let otherPool = words.filter { !$0.isNoun && $0.type != "pl" && !$0.de.contains(" ") && !$0.de.contains(",") }.map(\.de)
        var clozeCount = 0
        for gloss in glossary.dropFirst() where clozeCount < 1 {
            guard let sentence = allSentences.first(where: { containsWord($0, gloss.form) }) else { continue }
            let isNoun = gloss.art != nil
            let siblings = glossary.filter { $0.form != gloss.form && ($0.art != nil) == isNoun }.map(\.form)
            let pool = (siblings + (isNoun ? nounPool : otherPool).shuffled()).filter { $0.lowercased() != gloss.form.lowercased() }
            var wrong: [String] = []
            for item in pool where !wrong.contains(item) && wrong.count < 3 { wrong.append(item) }
            guard wrong.count == 3 else { continue }
            out.append(A1Question(id: id("c\(clozeCount)"), mode: .cloze, kind: .choice, label: label,
                                  prompt: blank(sentence, gloss.form), detail: t("reading.gap"), speakAfter: sentence,
                                  options: ([gloss.form] + wrong).shuffled(), answer: gloss.form,
                                  explanation: "\(sentence)\n\(gloss.display) = \(gloss.mean.text)"))
            clozeCount += 1
        }

        // 4. Put a sentence from the text back in order.
        if let sentence = allSentences.first(where: { (4...9).contains($0.split(separator: " ").count) }) {
            let tokens = sentence.split(separator: " ").map(String.init)
            var shuffled = tokens.shuffled()
            var tries = 0
            while shuffled == tokens && tries < 5 { shuffled.shuffle(); tries += 1 }
            out.append(A1Question(id: id("o0"), mode: .order, kind: .order, label: label, prompt: t("q.orderFromText"),
                                  detail: t("q.orderWords"), speakAfter: sentence, options: shuffled,
                                  answer: tokens.joined(separator: " "), explanation: sentence))
        }

        // 5. Dictation of a short sentence.
        if let sentence = allSentences.last(where: { (3...8).contains($0.split(separator: " ").count) }) {
            out.append(A1Question(id: id("d0"), mode: .write, kind: .typing, label: label, prompt: t("q.dictation"),
                                  speakFirst: sentence, answer: sentence, explanation: sentence))
        }
        return out
    }

    static func containsWord(_ sentence: String, _ form: String) -> Bool {
        sentence.split(separator: " ").contains { strip(String($0)).lowercased() == form.lowercased() }
    }

    private static func strip(_ token: String) -> String {
        token.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:„“\"()–…"))
    }

    private static func blank(_ sentence: String, _ form: String) -> String {
        var tokens = sentence.split(separator: " ").map(String.init)
        if let index = tokens.firstIndex(where: { strip($0).lowercased() == form.lowercased() }),
           let range = tokens[index].range(of: strip(tokens[index])) {
            tokens[index].replaceSubrange(range, with: "_____")
        }
        return tokens.joined(separator: " ")
    }
}
