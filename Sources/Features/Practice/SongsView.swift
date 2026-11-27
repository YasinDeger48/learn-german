import AVFoundation
import SwiftUI

// MARK: - Şarkılar (songs)
// Real karaoke: traditional German children's songs (public domain), our instrumental made from the notes
// (tools/karaoke.py). Every syllable lights up on its note and the child sings; tapping the line lets Lina read it
// (recorded natural voice). Lina dances to the beat (Codex frames lina-dance-1…6). After the song: a 3-question
// mini quiz. Design: https://claude.ai/artifact/FSbTPDqXpBwpSFzBpq83JE

/// One sung syllable; `join` = the next syllable belongs to the same word ("Al" + "le").
struct SongSyllable: Decodable, Hashable {
    let text: String
    let join: Bool
    let start: Double
    let end: Double
}

struct SongLine: Decodable, Hashable {
    let part: String
    let who: String
    let de: String
    let tr: String
    let en: String
    let syl: [SongSyllable]?
    var meaning: String { localText(tr: tr, en: en, es: nil, fr: nil, it: nil, ku: nil, ar: nil) }
}

struct SongTiming: Decodable, Hashable {
    let start: Double
    let end: Double
    /// The free bar after a "Du" line, to sing it back.
    let echo: [Double]?
}

struct Song: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let title_tr: String?
    let title_en: String?
    let bpm: Int
    let lines: [SongLine]
    let questions: [DailyQuestion]
    let timeline: [SongTiming]?
    let duration: Double?
    let audio: String?
    /// Changes when the music is made again, so the cached file is replaced.
    let hash: String?

    var meaning: String { localText(tr: title_tr ?? "", en: title_en ?? "", es: nil, fr: nil, it: nil, ku: nil, ar: nil) }
    var ready: Bool { audio != nil && (timeline?.count ?? 0) == lines.count }
}

enum SongBank {
    private struct File: Decodable { let songs: [Song] }
    private static let all: [String: [Song]] = Dictionary(uniqueKeysWithValues: ["a1", "a2", "b1", "b2"].map { level in
        (level, (Bundled.decode(File.self, "songs_\(level)")?.songs ?? []).filter(\.ready))
    })

    static func songs(_ level: String) -> [Song] { all[level.lowercased()] ?? [] }

    private static let finishedKey = "songsFinished"
    static var finished: Set<String> { Set(UserDefaults.standard.stringArray(forKey: finishedKey) ?? []) }
    static func markFinished(_ id: String) {
        var set = finished
        guard set.insert(id).inserted else { return }
        UserDefaults.standard.set(Array(set), forKey: finishedKey)
    }

    /// The song's questions as quiz questions (mode Hören, so they count there and in its mistakes).
    static func quiz(_ song: Song) -> [A1Question] {
        song.questions.enumerated().map { index, q in
            let options = q.type == "tf" ? ["Richtig", "Falsch"] : (q.options ?? [])
            let answer = options.indices.contains(q.answer) ? options[q.answer] : (options.first ?? "")
            return A1Question(id: "song-\(song.id)-\(index)", mode: .hoeren, kind: .choice, label: song.title,
                              prompt: q.q, options: options, answer: answer)
        }
    }
}

/// Downloads a song once (Caches/Songs) and plays it; `time` is read by the karaoke screen.
final class SongPlayer: ObservableObject {
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    @Published private(set) var playing = false
    private var player: AVAudioPlayer?

    private static var folder: URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Songs")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var time: Double { player?.currentTime ?? 0 }

    func load(_ song: Song, then start: @escaping () -> Void) {
        guard let path = song.audio else { return }
        let local = Self.folder.appendingPathComponent("\(song.id)-\(song.hash ?? "1").mp3")
        if FileManager.default.fileExists(atPath: local.path) {
            prepare(local)
            start()
            return
        }
        loading = true
        URLSession.shared.dataTask(with: TextAudioPlayer.base.appendingPathComponent(path)) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.loading = false
                guard let data, data.count > 1000, (response as? HTTPURLResponse)?.statusCode == 200,
                      (try? data.write(to: local, options: .atomic)) != nil else {
                    self.failed = true
                    return
                }
                self.prepare(local)
                start()
            }
        }.resume()
    }

    private func prepare(_ url: URL) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.enableRate = true
        player?.prepareToPlay()
    }

    func play(rate: Float) {
        player?.rate = rate
        player?.play()
        playing = player != nil
    }

    func pause() {
        player?.pause()
        playing = false
    }

    func restart(rate: Float) {
        player?.currentTime = 0
        play(rate: rate)
    }

    func setRate(_ rate: Float) { player?.rate = rate }

    /// After the last note the player stops by itself: show the play button again.
    func refresh() {
        if playing, player?.isPlaying == false { playing = false }
    }

    func stop() {
        player?.stop()
        playing = false
    }
}

// MARK: - List

struct SongsHomeView: View {
    let level: String
    @State private var finished = SongBank.finished

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(SongBank.songs(level).enumerated()), id: \.element.id) { index, song in
                    NavigationLink { SongPlayerView(song: song, number: index + 1) } label: { card(song, number: index + 1) }
                        .buttonStyle(.pressable)
                }
            }
            .padding(16)
        }
        .background(DS.ground.ignoresSafeArea())
        .navigationTitle(t("song.title"))
        .safeAreaInset(edge: .bottom) { AdBanner() }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { finished = SongBank.finished }
    }

    private func card(_ song: Song, number: Int) -> some View {
        let done = finished.contains(song.id)
        return HStack(spacing: 14) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.42, green: 0.25, blue: 0.84), Color(red: 0.23, green: 0.12, blue: 0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: done ? "checkmark" : "music.note")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(done ? Color(red: 0.5, green: 0.88, blue: 0.77) : Color(red: 1, green: 0.88, blue: 0.54))
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(t("song.number", number).uppercased()).font(.caption2.weight(.heavy)).foregroundColor(Color(red: 0.42, green: 0.25, blue: 0.84))
                Text(song.title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(DS.ink)
                Text(song.meaning).font(.caption).foregroundColor(DS.muted)
            }
            Spacer(minLength: 4)
            Text(t("exam.minutes", max(1, Int(((song.duration ?? 60) / 60).rounded()))))
                .font(.caption.weight(.semibold)).foregroundColor(DS.muted)
        }
        .padding(12)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Karaoke

struct SongPlayerView: View {
    let song: Song
    let number: Int
    @StateObject private var player = SongPlayer()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var time: Double = 0
    @State private var slow = false
    @State private var showTranslation = true
    @State private var ended = false
    private let clock = Timer.publish(every: 1.0 / 20, on: .main, in: .common).autoconnect()

    private static let gold = Color(red: 1, green: 0.88, blue: 0.54)
    private static let pink = Color(red: 1, green: 0.62, blue: 0.73)
    private static let dance = (1...6).compactMap { UIImage(named: "lina-dance-\($0)") }

    private var timeline: [SongTiming] { song.timeline ?? [] }
    private var beat: Double { 60.0 / Double(max(60, song.bpm)) }

    /// The line being sung: the last one that has started; the next one shows a moment early to read ahead.
    private var lineIndex: Int { timeline.lastIndex { $0.start - 0.35 <= time } ?? 0 }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.42, green: 0.25, blue: 0.84), Color(red: 0.23, green: 0.12, blue: 0.55),
                                    Color(red: 0.10, green: 0.06, blue: 0.27)],
                           center: .top, startRadius: 10, endRadius: 700)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                header
                dancer.frame(height: 230)
                lyrics
                Spacer(minLength: 0)
                progress
                controls
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .environment(\.colorScheme, .dark)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            player.load(song) { player.play(rate: slow ? 0.8 : 1) }
        }
        .onDisappear { player.stop() }
        .onReceive(clock) { _ in
            time = player.time
            player.refresh()
            // The player jumps back to 0 when it ends, so "the last second was reached" counts as the end.
            if let duration = song.duration, time >= duration - 1.0, !ended {
                ended = true
                SongBank.markFinished(song.id)
                StreakStore.shared.record()
                StreakStore.shared.addXP(15)
                BadgeStore.shared.refresh()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("\(song.level) · " + t("song.number", number)).font(.caption.weight(.heavy)).tracking(1.4).foregroundColor(Self.gold)
            Text(song.title).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(.white)
        }
        .padding(.top, 6)
    }

    private var dancer: some View {
        ZStack(alignment: .bottom) {
            Ellipse().fill(RadialGradient(colors: [Self.gold.opacity(0.45), .clear], center: .center, startRadius: 2, endRadius: 110))
                .frame(width: 220, height: 34)
            if !Self.dance.isEmpty {
                let frame: Int = {
                    guard player.playing, !reduceMotion else { return 0 }
                    return Int(time / beat) % min(5, Self.dance.count)
                }()
                Image(uiImage: Self.dance[frame]).resizable().scaledToFit()
                    .frame(height: 220)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
                    .accessibilityLabel(t("song.dancing"))
            }
        }
    }

    private var lyrics: some View {
        let index = lineIndex
        let line = song.lines.indices.contains(index) ? song.lines[index] : nil
        return VStack(spacing: 10) {
            Text(index > 0 ? song.lines[index - 1].de : " ")
                .font(.system(size: 15, design: .rounded)).foregroundColor(.white.opacity(0.4)).lineLimit(1)
            if let line {
                let recorded = WordAudio.shared.isRecorded(A1Line(s: -1, t: line.de))
                VStack(spacing: 8) {
                    Label(t("song.singAlong"), systemImage: "mic.fill")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color(red: 1, green: 0.36, blue: 0.54), in: Capsule())
                    karaokeText(line, index: index)
                    if showTranslation {
                        Text(line.meaning).font(.system(size: 15, design: .rounded)).foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    if recorded {
                        Label(t("song.tapToHear"), systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .onTapGesture {
                    // Lina reads the line slowly (natural voice only); the song waits meanwhile.
                    guard recorded else { return }
                    player.pause()
                    A1Speaker.shared.play([A1Line(s: -1, t: line.de)], slow: true, deviceVoice: false)
                }
                .accessibilityAddTraits(recorded ? .isButton : [])
                .accessibilityHint(recorded ? t("song.tapToHear") : "")
            }
            Text(song.lines.indices.contains(index + 1) ? song.lines[index + 1].de : " ")
                .font(.system(size: 15, design: .rounded)).foregroundColor(.white.opacity(0.55)).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    /// Each syllable lights up when its note starts: gold once sung, pink while it is being sung.
    private func karaokeText(_ line: SongLine, index: Int) -> some View {
        let syllables = line.syl ?? []
        let text: Text
        if syllables.isEmpty {
            text = Text(line.de).foregroundColor(.white)
        } else {
            text = syllables.enumerated().reduce(Text("")) { result, item in
                let (i, syllable) = item
                let space = i + 1 < syllables.count && !syllable.join ? " " : ""
                let color: Color = time >= syllable.end ? Self.gold : (time >= syllable.start ? Self.pink : .white.opacity(0.45))
                return result + Text(syllable.text + space).foregroundColor(color)
            }
        }
        return text
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
    }

    private var progress: some View {
        VStack(spacing: 10) {
            if player.loading {
                ProgressView().tint(.white)
                Text(t("song.loading")).font(.footnote).foregroundColor(.white.opacity(0.8))
            } else if player.failed {
                Text(t("song.failed")).font(.footnote).foregroundColor(.white.opacity(0.85)).multilineTextAlignment(.center)
            }
            if ended {
                NavigationLink {
                    A1QuizView(title: song.title) { SongBank.quiz(song) }
                } label: {
                    Label(t("song.quiz"), systemImage: "checkmark.bubble.fill")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.10, green: 0.06, blue: 0.27))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Self.gold, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(LinearGradient(colors: [Self.gold, Self.pink], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * CGFloat(min(1, time / max(1, song.duration ?? 1))))
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            roundButton("tortoise.fill", t("common.listenSlow"), selected: slow) {
                slow.toggle()
                player.setRate(slow ? 0.8 : 1)
            }
            roundButton("arrow.counterclockwise", t("song.restart"), selected: false) {
                ended = false
                player.restart(rate: slow ? 0.8 : 1)
            }
            Button {
                if player.playing { player.pause() } else { player.play(rate: slow ? 0.8 : 1) }
            } label: {
                Image(systemName: player.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color(red: 0.10, green: 0.06, blue: 0.27))
                    .frame(width: 72, height: 72)
                    .background(Self.gold, in: Circle())
                    .shadow(color: Self.gold.opacity(0.5), radius: 14)
            }
            .buttonStyle(.pressable)
            .disabled(player.loading || player.failed)
            .accessibilityLabel(player.playing ? t("lazy.pause") : t("lazy.play"))
            roundButton("character.bubble", t("lazy.translation"), selected: showTranslation) { showTranslation.toggle() }
        }
    }

    private func roundButton(_ icon: String, _ name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                .frame(width: 52, height: 48)
                .background(selected ? Self.pink.opacity(0.55) : Color.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private extension Song {
    /// "A1" from the id ("a1-song-01").
    var level: String { String(id.prefix(2)).uppercased() }
}

