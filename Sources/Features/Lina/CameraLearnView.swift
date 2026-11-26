import SwiftUI
import UIKit
import Vision
import VisionKit

// MARK: - Kamerayla öğren: scan German text, name objects, "Evde bul" game
// Text: Apple's live text scanner (VisionKit DataScanner, iOS 16, A12+). Objects: Vision's on-device image classifier,
// its English labels matched to our nouns by their English meaning. Design: https://claude.ai/artifact/BTCHF23AfJ8LFkq5DTBGAE

/// Vision's English labels → our nouns (by the English meaning: "chair", "the cup", "cup; mug" …).
enum VisionWords {
    /// "dining_table" → ["dining table", "table"]; "coffee_cup" → ["coffee cup", "cup"].
    static func keys(_ identifier: String) -> [String] {
        let phrase = identifier.replacingOccurrences(of: "_", with: " ").lowercased()
        var out = [phrase]
        if let last = phrase.split(separator: " ").last, String(last) != phrase { out.append(String(last)) }
        return out
    }

    /// English meaning of a word, split into plain keys.
    static func meanings(_ word: A1Word) -> [String] {
        let english = (word.mean.values["en"] ?? "").lowercased()
        return english.split(whereSeparator: { ",;/(".contains($0) }).map { part in
            var s = part.trimmingCharacters(in: CharacterSet(charactersIn: " )."))
            for article in ["the ", "a ", "an "] where s.hasPrefix(article) { s = String(s.dropFirst(article.count)) }
            return s
        }.filter { !$0.isEmpty }
    }

    /// Nouns by English key.
    static func index(_ words: [A1Word]) -> [String: A1Word] {
        var table: [String: A1Word] = [:]
        for word in words where word.isNoun {
            for key in meanings(word) where table[key] == nil { table[key] = word }
        }
        return table
    }

    /// The labels Vision sees in the image, best first (confidence above `minimum`).
    static func classify(_ image: UIImage, minimum: Float = 0.03) -> [(String, Float)] {
        guard let cg = image.cgImage else { return [] }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation(image), options: [:])
        guard (try? handler.perform([request])) != nil else { return [] }
        return (request.results ?? []).filter { $0.confidence >= minimum }.prefix(20).map { ($0.identifier, $0.confidence) }
    }

    /// Our nouns for the labels, best first, each once.
    static func match(_ labels: [(String, Float)], in table: [String: A1Word]) -> [A1Word] {
        var seen = Set<Int>()
        var out: [A1Word] = []
        for (label, _) in labels {
            for key in keys(label) {
                if let word = table[key], seen.insert(word.id).inserted { out.append(word) }
            }
        }
        return out
    }

    /// The nouns Vision can recognise at all (for the game).
    static func recognisable(_ table: [String: A1Word]) -> [A1Word] {
        let known = (try? VNClassifyImageRequest().supportedIdentifiers()) ?? []
        var seen = Set<Int>()
        var out: [A1Word] = []
        for identifier in known {
            for key in keys(identifier) {
                if let word = table[key], seen.insert(word.id).inserted { out.append(word) }
            }
        }
        return out
    }

    private static func orientation(_ image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    static func picture(_ word: A1Word, level: String) -> UIImage? {
        Covers.image("wp-\(level.lowercased())-\(word.id)")
    }
}

/// The three parts in one screen (route .camera).
struct CameraLearnView: View {
    @EnvironmentObject private var model: A1Model
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text(t("cam.text")).tag(0)
                Text(t("cam.object")).tag(1)
                Text(t("cam.game")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 10)
            switch tab {
            case 0: ScanTextPane()
            case 1: ObjectPane()
            default: FindGamePane()
            }
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("cam.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { DispatchQueue.global(qos: .userInitiated).async { WordLookup.shared.prepare() } }
    }
}

// MARK: Text

private struct ScanTextPane: View {
    @EnvironmentObject private var model: A1Model
    @State private var line = ""
    @State private var word: String?

    private var supported: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    var body: some View {
        VStack(spacing: 0) {
            if supported {
                ZStack(alignment: .bottom) {
                    TextScanner { tapped in
                        line = tapped
                        word = nil
                    }
                    .ignoresSafeArea(edges: .bottom)
                    if line.isEmpty {
                        Text(t("cam.tapText"))
                            .font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.black.opacity(0.55), in: Capsule())
                            .padding(.bottom, 20)
                    }
                }
            } else {
                Spacer()
                Label(t("cam.noScanner"), systemImage: "camera.metering.unknown")
                    .font(.subheadline).foregroundColor(DS.muted).multilineTextAlignment(.center).padding(24)
                Spacer()
            }
            if !line.isEmpty { WordSheet(line: line, word: $word) }
        }
    }
}

/// The words of the tapped line as chips; a chosen word shows its card.
private struct WordSheet: View {
    @EnvironmentObject private var model: A1Model
    let line: String
    @Binding var word: String?
    @State private var linaMeaning: String?
    @State private var asking = false

    private var words: [String] {
        line.split(whereSeparator: { !($0.isLetter || $0 == "-") }).map(String.init).filter { $0.count > 1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(words.enumerated()), id: \.offset) { _, item in
                        Button {
                            word = item
                            linaMeaning = nil
                        } label: {
                            Text(item).font(.system(size: 15, weight: .semibold))
                                .foregroundColor(word == item ? DS.onGold : DS.ink)
                                .padding(.horizontal, 12).frame(minHeight: 38)
                                .background(word == item ? DS.gold : DS.surface, in: Capsule())
                                .overlay(Capsule().stroke(DS.hairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let word {
                if let info = WordLookup.shared.info(for: word, glossary: []) {
                    WordCard(word: info.word, article: info.article, meaning: info.meaning, extra: info.extra,
                             poolWord: poolWord(info))
                } else if let linaMeaning {
                    WordCard(word: word, article: nil, meaning: linaMeaning, extra: t("cam.fromLina"), poolWord: nil)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("cam.unknown", word)).font(.subheadline).foregroundColor(DS.muted)
                        if LinaAI.isAvailable {
                            Button { askLina(word) } label: {
                                Label(asking ? t("lina.thinking") : t("lina.ask"), systemImage: "sparkles")
                                    .frame(minHeight: 40)
                            }
                            .buttonStyle(.bordered)
                            .disabled(asking)
                        }
                    }
                }
            } else {
                Text(t("cam.pickWord")).font(.subheadline).foregroundColor(DS.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.ground)
    }

    /// The noun of the open level, so it can go into the Tembel Mod pool.
    private func poolWord(_ info: WordInfo) -> A1Word? {
        model.content?.words.first { $0.isNoun && $0.de == info.word }
    }

    private func askLina(_ word: String) {
        asking = true
        let instructions = "You explain German words very briefly to a learner. Answer in \(LinaAI.explainLanguage): "
            + "the meaning in a few words, then the base form with its article if it is a noun. One line, no markdown."
        Task {
            let answer = await LinaAI.respond(instructions: instructions, prompt: "Word: \(word)\nContext: \(line)")
            asking = false
            linaMeaning = answer ?? t("lina.failed")
        }
    }
}

/// A word with its article, meaning, a speaker and "add to my pool".
private struct WordCard: View {
    @EnvironmentObject private var model: A1Model
    let word: String
    let article: String?
    let meaning: String
    let extra: String?
    let poolWord: A1Word?
    @State private var added = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let article {
                            Text(article).font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(a1ArticleColor(article), in: Capsule())
                        }
                        Text(word).font(.system(size: 28, weight: .heavy)).foregroundColor(DS.ink)
                            .minimumScaleFactor(0.6).lineLimit(1)
                    }
                    Text(meaning).font(.system(size: 18, weight: .semibold)).foregroundColor(DS.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    if let extra, !extra.isEmpty { Text(extra).font(.caption).foregroundColor(DS.muted) }
                }
                Spacer(minLength: 0)
                Button { A1Speaker.shared.say([article, word].compactMap { $0 }.joined(separator: " ")) } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        .frame(width: 50, height: 50).background(DS.night, in: Circle())
                }
                .accessibilityLabel(t("common.listen"))
            }
            if let poolWord {
                Button {
                    var pool = LazyPool.ids(model.level)
                    pool.insert(poolWord.id)
                    LazyPool.save(pool, level: model.level)
                    added = true
                } label: {
                    Label(added ? t("cam.added") : t("cam.addToPool"), systemImage: added ? "checkmark" : "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DS.onGold)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(added)
            }
        }
        .padding(14)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: word) { _ in added = false }
    }
}

/// Apple's live text scanner; a tap on a recognised line hands its text over.
private struct TextScanner: UIViewControllerRepresentable {
    let onTap: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text(languages: ["de-DE"])],
                                                recognizesMultipleItems: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onTap: (String) -> Void
        init(onTap: @escaping (String) -> Void) { self.onTap = onTap }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item { onTap(text.transcript) }
        }
    }
}

// MARK: Object

private struct ObjectPane: View {
    @EnvironmentObject private var model: A1Model
    @State private var showCamera = false
    @State private var photo: UIImage?
    @State private var found: [A1Word] = []
    @State private var labels: [(String, Float)] = []
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(height: 240).frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 44)).foregroundColor(DS.muted)
                        Text(t("cam.objectIntro")).font(.subheadline).foregroundColor(DS.muted).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                if working { ProgressView() }
                if let best = found.first {
                    WordCard(word: best.de, article: best.type, meaning: best.mean.text,
                             extra: best.plural.map { t("lazy.plural", "die \($0)") }, poolWord: best)
                    if found.count > 1 {
                        HStack(spacing: 6) {
                            Text(t("cam.orMaybe")).font(.caption).foregroundColor(DS.muted)
                            ForEach(found.dropFirst().prefix(3)) { other in
                                Button { found = [other] + found.filter { $0.id != other.id } } label: {
                                    (Text(other.type + " ").foregroundColor(a1ArticleColor(other.type)) + Text(other.de).foregroundColor(DS.ink))
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 10).frame(minHeight: 32)
                                        .background(DS.surface, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else if photo != nil && !working {
                    Text(t("cam.noMatch")).font(.subheadline).foregroundColor(DS.muted).multilineTextAlignment(.center)
                }
                Button { showCamera = true } label: {
                    Label(photo == nil ? t("cam.takePhoto") : t("cam.takeAnother"), systemImage: "camera.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.onGold)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(DS.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(!PhotoCapture.available)
                if !PhotoCapture.available {
                    Text(t("cam.noCamera")).font(.footnote).foregroundColor(DS.muted)
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showCamera) {
            PhotoCapture { image in
                photo = image
                recognise(image)
            }
            .ignoresSafeArea()
        }
    }

    private func recognise(_ image: UIImage) {
        working = true
        found = []
        let words = model.content?.words ?? []
        DispatchQueue.global(qos: .userInitiated).async {
            let seen = VisionWords.classify(image)
            let matched = VisionWords.match(seen, in: VisionWords.index(words))
            DispatchQueue.main.async {
                labels = seen
                found = matched
                working = false
            }
        }
    }
}

/// The system camera for one photo.
struct PhotoCapture: UIViewControllerRepresentable {
    static var available: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoCapture
        init(_ parent: PhotoCapture) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPhoto(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

// MARK: Game: Evde bul

private struct FindGamePane: View {
    @EnvironmentObject private var model: A1Model
    private static let rounds = 5

    @State private var targets: [A1Word] = []
    @State private var round = 0
    @State private var found: [Bool] = []
    @State private var showCamera = false
    @State private var checking = false
    @State private var result: Bool?

    private var target: A1Word? { targets.indices.contains(round) ? targets[round] : nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if targets.isEmpty {
                    ProgressView().padding(40)
                } else if round >= targets.count {
                    finished
                } else if let target {
                    progress
                    Text(t("cam.findTitle")).font(.caption.weight(.heavy)).tracking(2).foregroundColor(DS.goldDeep)
                    LinaAvatar(size: 110, mood: result == true ? .happy : (result == false ? .sad : .curious))
                    VStack(spacing: 8) {
                        Text(t("cam.findSub")).font(.subheadline).foregroundColor(DS.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(target.type).font(.system(size: 18, weight: .heavy)).foregroundColor(.white)
                                .padding(.horizontal, 9).padding(.vertical, 2)
                                .background(a1ArticleColor(target.type), in: Capsule())
                            Text(target.de).font(.system(size: 36, weight: .heavy)).foregroundColor(DS.ink)
                        }
                        HStack(spacing: 8) {
                            Button { A1Speaker.shared.say(target.withArticle) } label: {
                                Label(t("common.listen"), systemImage: "speaker.wave.2.fill").frame(minHeight: 40)
                            }
                            .buttonStyle(.bordered)
                            Button { hint = true } label: {
                                Label(t("cam.hint"), systemImage: "lightbulb").frame(minHeight: 40)
                            }
                            .buttonStyle(.bordered)
                        }
                        if hint {
                            Text(target.mean.text).font(.headline).foregroundColor(DS.ink)
                            if let picture = VisionWords.picture(target, level: model.level) {
                                Image(uiImage: picture).resizable().scaledToFit().frame(height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    if checking { ProgressView() }
                    if let result {
                        Text(result ? t("cam.found") : t("cam.notFound"))
                            .font(.headline).foregroundColor(result ? DS.success : DS.error)
                            .multilineTextAlignment(.center)
                    }
                    if result == true {
                        primary(t("quiz.next"), icon: "arrow.right") { next(found: true) }
                    } else {
                        primary(t("cam.openCamera"), icon: "camera.fill") { showCamera = true }
                            .disabled(!PhotoCapture.available || checking)
                        Button(t("cam.skip")) { next(found: false) }
                            .font(.subheadline.weight(.semibold)).foregroundColor(DS.muted)
                            .frame(minHeight: 44)
                    }
                }
            }
            .padding(.horizontal, DS.gutter)
            .padding(.bottom, 24)
        }
        .onAppear { setUp(force: false) }
        .sheet(isPresented: $showCamera) {
            PhotoCapture { image in check(image) }.ignoresSafeArea()
        }
    }

    @State private var hint = false

    private var progress: some View {
        HStack(spacing: 5) {
            ForEach(0..<Self.rounds, id: \.self) { i in
                Capsule()
                    .fill(i < found.count ? (found[i] ? DS.gold : DS.hairline) : (i == round ? DS.ink : DS.chip))
                    .frame(width: i == round ? 30 : 20, height: 8)
            }
        }
        .accessibilityLabel(t("match.round", min(round + 1, Self.rounds), Self.rounds))
    }

    private var finished: some View {
        VStack(spacing: 12) {
            LinaAvatar(size: 120, mood: .happy)
            Text(t("cam.gameDone", found.filter { $0 }.count, Self.rounds))
                .font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(DS.ink)
                .multilineTextAlignment(.center)
            primary(t("run.again"), icon: "arrow.counterclockwise") { setUp(force: true) }
        }
        .padding(.top, 30)
    }

    private func primary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DS.onGold)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(DS.gold, in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    private func setUp(force: Bool) {
        guard force || targets.isEmpty else { return }
        let words = model.content?.words ?? []
        DispatchQueue.global(qos: .userInitiated).async {
            let pool = VisionWords.recognisable(VisionWords.index(words)).shuffled().prefix(Self.rounds)
            DispatchQueue.main.async {
                targets = Array(pool)
                round = 0
                found = []
                result = nil
                hint = false
            }
        }
    }

    private func check(_ image: UIImage) {
        guard let target else { return }
        checking = true
        result = nil
        let words = model.content?.words ?? []
        DispatchQueue.global(qos: .userInitiated).async {
            let matched = VisionWords.match(VisionWords.classify(image, minimum: 0.02), in: VisionWords.index(words))
            let ok = matched.prefix(8).contains { $0.id == target.id }
            DispatchQueue.main.async {
                checking = false
                result = ok
                AnswerSound.play(correct: ok)
                if ok { A1Speaker.shared.say(target.withArticle) }
            }
        }
    }

    private func next(found ok: Bool) {
        found.append(ok)
        result = nil
        hint = false
        round += 1
        if round >= targets.count, found.contains(true) {
            StreakStore.shared.record()
            StreakStore.shared.addXP(found.filter { $0 }.count * 5)
        }
    }
}

/// The card on Today (only on phones with a camera).
struct CameraLearnCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(DS.onGold)
                .frame(width: 60, height: 60)
                .background(DS.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(t("cam.badge")).font(.system(size: 11, weight: .heavy)).tracking(1.6).foregroundColor(DS.gold)
                Text(t("cam.title")).font(.system(size: 21, weight: .heavy, design: .rounded)).foregroundColor(.white)
                Text(t("cam.cardSub")).font(.footnote).foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(LinearGradient(colors: [Color(red: 0.20, green: 0.22, blue: 0.28), Color(red: 0.06, green: 0.07, blue: 0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("cam.title"))
        .accessibilityHint(t("cam.cardSub"))
    }
}
