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
| `memorize.json` (Mutlaka bil) | `tools/memorize.py` |
| `verbs_<level>.json` (verb lab) | `tools/verblab.py` |
| Reading / word audio, background sounds | `tools/audio.py`, `tools/word_audio.py`, `tools/audio_pad.py`, `tools/ambience.py` |

## When you are done

Tell the owner, in Turkish and in a few lines: what you changed (files), what you did not do, and what still needs
a build or a test on the phone. Do not claim it works if it was not built.
