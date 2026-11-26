# Notes for coding agents (Codex, Claude and others)

Deschly is an iOS app (SwiftUI, iOS 16; widgets iOS 17) for learning German, for Turkish and English speakers.
The owner talks to agents in Turkish: answer him in Turkish. Code, comments, commit messages and UI keys stay English.

## Golden rules

1. **Do only what was asked.** If the task is "add ambient sound to Hören", change only what that needs.
   No refactoring, renaming, re-formatting, "improving" or deleting anything outside the task.
2. **Several agents work in this repo at the same time.** Run `git status` before you start and before you stage.
   Never edit, revert or stage a file you did not change in this task. Stage files one by one by path:
   never `git add -A`, `git add .` or `git add <folder>`.
3. **Git:** commit only when the owner asks; never push, tag, rebase or amend someone else's commit.
   Never run `git reset --hard`, `git checkout -- <file>`, `git restore <file>`, `git clean` or `git stash`
   on files that are not yours: that destroys other agents' work.
4. **Do not touch** unless the task is exactly about them:
   - `Info.plist` (`DeschlyFreeForAll`, AdMob ids, usage texts), `project.yml`, bundle ids, signing
   - `.github/workflows/`, `ci/`
   - StoreKit product ids (`com.yasindeger.almanca.pro.*`)
   - other agents' strings in `Resources/i18n/` (add new keys only)
5. **Content files are the source of truth.** `Resources/content/*.json` are written by the tools in `tools/`
   (see below). Do not hand-edit the minified JSON and do not regenerate a whole file to change one part:
   add a small tool or extend the existing one.
   Hand edits made in Deschly Studio are recorded in `tools/content_edits.json`. After you regenerate a content file,
   run `python -I -X utf8 tools/content_edits.py` so they are applied again (`tools/units.py` and
   `tools/publish_content.py` already do this).
6. **No secrets in the repo.** API keys live in `../tts/anahtarlar.txt` (never commit it) and in GitHub Secrets.
7. **This PC cannot build Swift** (Windows; CI builds on GitHub). Keep changes small and compile-safe: every type
   and function you call must exist. Do not leave half-finished code that references missing types.
8. Every UI text goes through `t("key")` and must exist in all seven files: `strings_tr.json`, `strings_en.json`,
   `strings_es.json`, `strings_fr.json`, `strings_it.json`, `strings_ku.json` (Kurmancî), `strings_ar.json` (Arabic, right to left).
   New keys may start in English in es/fr/it/ku/ar; `tools/ui_strings.py` sends the untranslated ones to ChatGPT. Line endings LF.

## Reuse what exists (do not build a second copy)

| Need | Use |
|---|---|
| Speak German text | `A1Speaker` (`Sources/Core/Services/Speech.swift`); single words play recorded audio via `WordAudio` |
| Recorded reading voices | `TextAudioPlayer` (`Sources/Core/Services/TextAudio.swift`), files from `tools/audio.py` |
| **Background / ambient sound** | **`AmbiencePlayer`** (`TextAudio.swift`). Loops already exist on the website: `audio/ambience/<kind>.m4a`, kinds `bus, train, cafe, office, shop, home, nature, rain, school, street` (made by `tools/ambience.py`, CC0 from Freesound). Add a method there if you need one; do not add another player or bundle new audio files without asking. |
| Speech recognition | `SpeechListener`, `SpeechScore` (`Sources/Core/Services/SpeechListener.swift`) |
| Remote content | `ContentStore` / `ContentUpdater`; publish with `tools/publish_content.py` |
| Quizzes | `A1QuizView` + `A1Question` |

## Content tools

| File | Tool |
|---|---|
| `a1.json` … `b2.json` grammar exercises | `tools/grammar_request.py`, `tools/grammar_import.py` |
| `lexicon.json` (meaning of every text word) | `tools/lexicon.py` |
| `speaking.json` | `tools/speaking.py`, `tools/speaking_a1_more.py` |
| `writing.json` | `tools/writing.py` |
| Hand edits from Deschly Studio (any file) | `tools/content_edits.py` (`tools/content_edits.json`) |
| Broken umlauts (`w??rde`) in content | `tools/fix_broken_text.py` |
| `memorize.json` (Mutlaka bil) | `tools/memorize.py` |
| `verbs_<level>.json` (verb lab) | `tools/verblab.py` |
| `phone_<level>.json` (Telefonda: calls, voicemail; phone sound made by `tools/audio.py`) | `tools/phone.py` |
| Reading / word audio, background sounds | `tools/audio.py`, `tools/word_audio.py`, `tools/audio_pad.py`, `tools/ambience.py` |

## Content jobs list (Codex)

The owner says "ChatGPT" for Codex. The jobs Codex does for the content (pictures, verb lab answers, stories …) are in
`../icerik/CHATGPT_YAPILACAKLAR.txt`, **in priority order, A1 first**. Claude writes the request files and that list.

- Work the list **top to bottom**: it comes before the content translations below. Continue the translations when
  the list is empty or the next job is blocked.
- **Work in parallel whenever you can:** jobs that do not depend on each other (different request files, pictures
  next to verb answers, the translations next to the list) run at the same time (parallel tasks / sub-agents),
  still started in list order. Each parallel task writes only its own answer files; only one task at a time edits
  `CHATGPT_YAPILACAKLAR.txt` or a translation memory file (`tools/i18n/content_<lang>.json`).
- Each job names its request file(s) and where to save the answer. Write the answer exactly in the format the request
  asks for; nothing else in the file.
- **Complete answers only:** a verb request with 15 verbs needs all 15 in the answer (cevap_04 and cevap_06 were cut
  off after 5). If an answer gets long, split it (`A1_fiil_cevap_07a.txt`, `…07b.txt`) rather than stopping halfway.
- Pictures: follow the STYLE paragraph of the prompt file; save under the exact name it gives.
- Do not import answers or change `Resources/`: Claude imports them (`tools/verblab.py`, `tools/stories.py`, `tools/phone.py`,
  `tools/word_pictures.py`, `tools/vocab_pictures.py`), then removes the finished job from the list.
- When a job is done, write one line under it: `Durum: [HAZIR] <what is ready>`; do not delete or reorder the list.

## Content translations (the agent that translates them, e.g. Codex)

One agent translates the learner-language content at a time; the owner chose Codex for it (2026-11-26).
Claude does not touch these translations meanwhile.

- **Where:** `tools/i18n/content_<lang>.json` (English text → translation) is the memory; write new entries there
  and put them into the content files with `tools/translate.py` (its `apply()`; `status` shows what is left).
  `python -I -X utf8 tools/translate.py status` lists the missing texts per language and level.
- **Order** (after Spanish B1): Spanish B2 → Kurmancî B1 → Kurmancî B2 → French, Italian, Arabic A2 →
  their B1 → their B2. Keep finishing one language/level before the next.
- **Rules** (same as the ChatGPT requests, `tools/translate.py rules()`): translate from the English; the Turkish is
  only context. Keep German words and sentences, grammar terms (Akkusativ, Perfekt, der/die/das), placeholders
  `{0}`, emoji and line breaks unchanged. Short and natural, informal "you" (tú / tu / tu / tu / أنت).
  Kurmancî: Latin script (Hawar: ç ê î ş û), not Sorani, not Arabic script. Arabic: Modern Standard Arabic,
  digits 0-9.
- **Do not** run `tools/gtranslate.py` (the owner's Google quota) and do not change other files.
- **Progress:** after each language/level, add one line at the end of `../icerik/CHATGPT_YAPILACAKLAR.txt`
  (append only). When everything is done, write "[OK] Tüm çeviriler bitti" there and tell the owner.
- After a level is finished, `python -I -X utf8 tools/publish_content.py` puts it on the website folder (it signs
  the manifest); the owner uploads the site. Commit only when the owner asks.

## When you are done

Tell the owner, in Turkish and in a few lines: what you changed (files), what you did not do, and what still needs
a build or a test on the phone. Do not claim it works if it was not built.
