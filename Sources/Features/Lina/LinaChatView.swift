import SwiftUI

// MARK: - Lina ile mesajlaş (role play with Apple's on-device model)
// A scene, then a chat: Lina plays her role in simple German at the learner's level, translates her replies and
// notes a correction (real mistake) or a more natural alternative under the learner's message.
// Design: https://claude.ai/artifact/BTCHF23AfJ8LFkq5DTBGAE (artboard 7).

struct LinaScene: Identifiable, Hashable {
    let id: String
    let icon: String
    /// Scene and Lina's role for the model (English is the model's best instruction language).
    let scene: String
    let role: String

    var title: String { t("lina.scene.\(id)") }
    var sub: String { t("lina.sceneSub.\(id)") }

    static let all: [LinaScene] = [
        LinaScene(id: "cafe", icon: "cup.and.saucer.fill", scene: "a café in Cologne; the learner is a guest who orders",
                  role: "the waiter"),
        LinaScene(id: "meet", icon: "hand.wave.fill", scene: "meeting someone new at a language course party",
                  role: "a friendly new course mate who asks about name, origin, work and hobbies"),
        LinaScene(id: "shop", icon: "cart.fill", scene: "a clothes shop; the learner wants to buy a jacket",
                  role: "the shop assistant"),
        LinaScene(id: "way", icon: "map.fill", scene: "a street in Berlin; the learner asks the way to the station",
                  role: "a helpful passer-by"),
        LinaScene(id: "doctor", icon: "cross.case.fill", scene: "a doctor's practice; the learner feels ill",
                  role: "the doctor who asks about the symptoms"),
        LinaScene(id: "phone", icon: "phone.fill", scene: "a phone call; the learner wants to make an appointment at the hairdresser",
                  role: "the hairdresser's receptionist"),
        LinaScene(id: "free", icon: "bubble.left.and.bubble.right.fill", scene: "a relaxed chat between friends about the day, hobbies and plans",
                  role: "Lina, the learner's cheerful friend"),
    ]
}

/// The scene list (route .linaChat).
struct LinaChatHomeView: View {
    let level: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    LinaAvatar(size: 64, mood: .happy)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("lina.chatTitle")).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(DS.ink)
                        Text(t("lina.chatIntro", level)).font(.subheadline).foregroundColor(DS.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(LinaScene.all) { scene in
                        NavigationLink { LinaChatView(scene: scene, level: level) } label: { tile(scene) }
                            .buttonStyle(.pressable)
                    }
                }
                Label(t("lina.onDevice"), systemImage: "lock.shield.fill").font(.footnote).foregroundColor(DS.muted)
            }
            .padding(.horizontal, DS.gutter)
            .padding(.vertical, 12)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("lina.chatTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ scene: LinaScene) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: scene.icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.onGold)
                .frame(width: 42, height: 42)
                .background(DS.gold, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            Text(scene.title).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(DS.ink)
                .multilineTextAlignment(.leading)
            Text(scene.sub).font(.caption).foregroundColor(DS.muted).multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// The chat itself.
struct LinaChatView: View {
    let scene: LinaScene
    let level: String
    @StateObject private var chat: LinaChat
    @State private var draft = ""
    @State private var hints: [String] = []
    @State private var hinting = false
    @AppStorage("lina.showTranslation") private var showTranslation = true
    @FocusState private var typing: Bool

    init(scene: LinaScene, level: String) {
        self.scene = scene
        self.level = level
        _chat = StateObject(wrappedValue: LinaChat.rolePlay(scene: scene.scene, role: scene.role, level: level))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("lina.roleNote", scene.title))
                            .font(.caption).foregroundColor(DS.muted)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(DS.chip, in: Capsule())
                            .frame(maxWidth: .infinity)
                        ForEach(chat.messages) { message in
                            LinaBubble(message: message, showTranslation: showTranslation).id(message.id)
                        }
                        if chat.busy {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(t("lina.writing")).font(.footnote).foregroundColor(DS.muted)
                            }
                            .id("busy")
                        }
                        if chat.failed {
                            Text(t("lina.failed")).font(.footnote).foregroundColor(DS.error)
                        }
                    }
                    .padding(14)
                }
                .onChange(of: chat.messages.count) { _ in
                    guard let last = chat.messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
                .onChange(of: chat.busy) { busy in
                    if busy { withAnimation { proxy.scrollTo("busy", anchor: .bottom) } }
                }
            }
            suggestions
            inputBar
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(scene.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showTranslation.toggle() } label: {
                    Image(systemName: showTranslation ? "character.bubble.fill" : "character.bubble")
                }
                .accessibilityLabel(t("lazy.translation"))
            }
        }
        .onAppear { chat.start() }
        .onDisappear { A1Speaker.shared.stop() }
    }

    /// "What should I say?": two short German replies Lina suggests; a tap puts one into the box.
    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(hints, id: \.self) { hint in
                    Button { draft = hint; typing = true } label: { chip(hint, muted: false) }
                        .buttonStyle(.plain)
                }
                Button { suggest() } label: {
                    if hinting { ProgressView().frame(minWidth: 60, minHeight: 36) } else { chip(t("lina.whatToSay"), muted: true) }
                }
                .buttonStyle(.plain)
                .disabled(hinting || chat.busy || chat.messages.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    private func chip(_ text: String, muted: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: muted ? .regular : .semibold))
            .foregroundColor(muted ? DS.muted : DS.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(DS.surface, in: Capsule())
            .overlay(Capsule().stroke(DS.hairline, lineWidth: 1))
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(t("lina.inputPlaceholder"), text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($typing)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DS.hairline, lineWidth: 1))
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(DS.onGold)
                    .frame(width: 46, height: 46)
                    .background(DS.gold, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.busy)
            .accessibilityLabel(t("lina.send"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func send() {
        let text = draft
        draft = ""
        hints = []
        chat.send(text)
    }

    private func suggest() {
        guard let last = chat.messages.last(where: { $0.fromLina }) else { return }
        hinting = true
        let instructions = "You help a German learner (level \(level)) answer in a role play. Reply with exactly two short, "
            + "different, natural German answers the learner could give, one per line, nothing else."
        Task {
            let answer = await LinaAI.respond(instructions: instructions, prompt: "Lina said: \(last.text)")
            hinting = false
            hints = (answer ?? "").split(separator: "\n")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " -•*0123456789.)\"„“")) }
                .filter { !$0.isEmpty }
                .prefix(2).map { $0 }
        }
    }
}

/// One message: Lina's (with translation and a speaker) or the learner's (with Lina's correction or alternative).
struct LinaBubble: View {
    let message: LinaMessage
    let showTranslation: Bool

    var body: some View {
        if message.fromLina {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(message.text).font(.system(size: 16)).foregroundColor(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if showTranslation && !message.translation.isEmpty {
                        Text(message.translation).font(.footnote).foregroundColor(DS.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.surface, in: UnevenBubbleShape(mine: false))
                .overlay(UnevenBubbleShape(mine: false).stroke(DS.hairline, lineWidth: 1))
                Button { A1Speaker.shared.say(message.text) } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 13, weight: .bold)).foregroundColor(DS.muted)
                        .frame(width: 36, height: 36)
                        .background(DS.chip, in: Circle())
                }
                .accessibilityLabel(t("common.listen"))
                Spacer(minLength: 30)
            }
        } else {
            VStack(alignment: .trailing, spacing: 5) {
                Text(message.text).font(.system(size: 16)).foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(DS.night, in: UnevenBubbleShape(mine: true))
                if !message.correction.isEmpty {
                    note(title: t("lina.correction"), text: message.correction, detail: message.why,
                         fill: DS.errorSoft, ink: DS.error)
                } else if !message.alternative.isEmpty {
                    note(title: t("lina.alternative"), text: message.alternative, detail: "",
                         fill: DS.successSoft, ink: DS.success)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
        }
    }

    /// Tap: Lina reads the corrected or more natural sentence.
    private func note(title: String, text: String, detail: String, fill: Color, ink: Color) -> some View {
        Button { A1Speaker.shared.say(text) } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.weight(.bold)).foregroundColor(ink)
                Text(text).font(.subheadline.weight(.semibold)).foregroundColor(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundColor(DS.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(t("common.listen"))
    }
}

/// A speech bubble with one sharp corner (top left for Lina, bottom right for the learner).
struct UnevenBubbleShape: Shape {
    let mine: Bool

    func path(in rect: CGRect) -> Path {
        let big: CGFloat = 16, small: CGFloat = 4
        let tl = mine ? big : small, tr = big, br = mine ? small : big, bl = big
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// "Lina'ya sor": questions about the text being read (a sheet from the reading screen).
struct LinaAskView: View {
    let title: String
    @StateObject private var chat: LinaChat
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss

    init(title: String, text: String, level: String) {
        self.title = title
        _chat = StateObject(wrappedValue: LinaChat.aboutText(title: title, text: text, level: level))
    }

    private var starters: [String] { [t("lina.askSummary"), t("lina.askWords"), t("lina.askGrammar"), t("lina.askQuiz")] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            LinaAvatar(size: 44, mood: .curious)
                            Text(t("lina.askIntro")).font(.subheadline).foregroundColor(DS.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if chat.messages.isEmpty {
                            ForEach(starters, id: \.self) { starter in
                                Button { chat.send(starter) } label: {
                                    Text(starter).font(.system(size: 15, weight: .semibold)).foregroundColor(DS.ink)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                        .padding(.horizontal, 14)
                                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DS.hairline, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        ForEach(chat.messages) { message in
                            LinaBubble(message: message, showTranslation: false)
                        }
                        if chat.busy {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(t("lina.thinking")).font(.footnote).foregroundColor(DS.muted)
                            }
                        }
                        if chat.failed { Text(t("lina.failed")).font(.footnote).foregroundColor(DS.error) }
                    }
                    .padding(16)
                }
                HStack(spacing: 8) {
                    TextField(t("lina.askPlaceholder"), text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(DS.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(DS.hairline, lineWidth: 1))
                    Button {
                        chat.send(draft)
                        draft = ""
                    } label: {
                        Image(systemName: "arrow.up").font(.system(size: 17, weight: .bold)).foregroundColor(DS.onGold)
                            .frame(width: 46, height: 46).background(DS.gold, in: Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.busy)
                    .accessibilityLabel(t("lina.send"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .background(DS.ground.ignoresSafeArea())
            .navigationTitle(t("lina.ask"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(t("common.done")) { dismiss() } }
            }
        }
    }
}

/// "Lina değerlendirsin": Lina's review under a checked writing task.
struct LinaReviewCard: View {
    let task: String
    let points: [String]
    let text: String
    let level: String
    @State private var review: LinaReview?
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let review {
                HStack(alignment: .top, spacing: 10) {
                    LinaAvatar(size: 40, mood: .happy)
                    Text(review.praise).font(.callout.weight(.semibold)).foregroundColor(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(review.fixes.enumerated()), id: \.offset) { _, fix in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fix.wrong).font(.subheadline).strikethrough().foregroundColor(DS.error)
                        Text(fix.right).font(.subheadline.weight(.bold)).foregroundColor(DS.success)
                        if !fix.why.isEmpty { Text(fix.why).font(.caption).foregroundColor(DS.muted) }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if !review.tip.isEmpty {
                    Label(review.tip, systemImage: "lightbulb.fill").font(.footnote).foregroundColor(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(t("lina.suggestionNote")).font(.caption2).foregroundColor(DS.muted)
            } else if busy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(t("lina.reading")).font(.footnote).foregroundColor(DS.muted)
                }
            } else {
                Button(action: start) {
                    Label(t("lina.review"), systemImage: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(DS.goldDeep)
                if failed { Text(t("lina.failed")).font(.footnote).foregroundColor(DS.error) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: text) { _ in review = nil }
    }

    private func start() {
        busy = true
        failed = false
        Task {
            let result = await LinaAI.reviewWriting(task: task, points: points, text: text, level: level)
            busy = false
            if let result { review = result } else { failed = true }
        }
    }
}

/// The card on Today (only when the model is available).
struct LinaChatCard: View {
    var body: some View {
        HStack(spacing: 14) {
            LinaAvatar(size: 64, mood: .happy)
            VStack(alignment: .leading, spacing: 3) {
                Text(t("lina.badge")).font(.system(size: 11, weight: .heavy)).tracking(1.6).foregroundColor(DS.gold)
                Text(t("lina.chatTitle")).font(.system(size: 21, weight: .heavy, design: .rounded)).foregroundColor(.white)
                Text(t("lina.cardSub")).font(.footnote).foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DS.onGold)
                .frame(width: 44, height: 44)
                .background(DS.gold, in: Circle())
        }
        .padding(14)
        .background(LinearGradient(colors: [Color(red: 0.98, green: 0.55, blue: 0.40), Color(red: 0.78, green: 0.25, blue: 0.42)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("lina.chatTitle"))
        .accessibilityHint(t("lina.cardSub"))
    }
}
