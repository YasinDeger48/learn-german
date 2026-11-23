# Deschly architecture

Deschly is a German learning app for speakers of Turkish, English, Spanish, French and Italian. There are no accounts and no server: everything ships inside the app and progress stays on the device.

The design keeps **content and UI text platform-neutral** (JSON in `Resources/`), so a future web or Android app can reuse them unchanged. Only the screens and the small engines are platform code.

## Layout

```
Resources/                    shared by every platform
  content/a1.json             level content (words, grammar, texts, listening), multi-language
  content/daily_a1.json       daily reading texts with glossary and questions
  content/lessons.json        YouTube video lessons
  i18n/strings_<lang>.json    UI strings, placeholders {0} {1}
  Fonts/                      DeschlyDisplay (Bricolage Grotesque), DeschlyText (Geist), OFL
  Images/lina.png             Lina, the mascot

Sources/                      iOS (SwiftUI, iOS 16+)
  App/                        entry point, root tabs, floating tab bar, routes
  Core/Localization           AppLanguage, Localizer, t(), LocText
  Core/Content                Codable models for the JSON files
  Core/Engine                 question bank, reading quiz, German numbers
  Core/Store                  progress (A1Model), daily reading (DailyModel), backup
  Core/Services               speech (AVSpeechSynthesizer), local reminders
  DesignSystem/               colours, fonts, buttons, rows, Lina avatar
  Features/<Screen>/          Onboarding, Today, Reading, Levels, Practice, Videos, Settings

tools/                        Python build scripts for the content (run on Windows)
docs/                         this file
```

## Data flow

1. `tools/a1_extras.py` and `tools/build_core.py` produce `tools/data/a1_raw.json` (Turkish source).
2. `tools/pack_content.py` turns every learner-language text into `{"tr": "...", "en": "...", ...}`, taking translations from `tools/i18n/<lang>.json` (keyed by stable ids such as `w.123`, `w.123.ex.0`, `g.4.rule`). `--missing en` lists what still needs translating.
3. `tools/build_daily.py a1` turns `tools/daily/a1_*.txt` into `daily_a1.json` and checks that every glossary word appears in its text.
4. The app decodes the JSON at launch. `LocText.text` picks the learner's language, then English, then Turkish.

```
python -I -X utf8 tools/pack_content.py tools/data/a1_raw.json Resources/content/a1.json
python -I -X utf8 tools/build_daily.py a1
```

## Rules for new code

- UI text only through `t("key")`; add the key to all five `strings_*.json` files.
- Content text only through `LocText`; never hard-code Turkish or English content in Swift.
- Question ids must stay stable: progress ("seen", "correct", "Hatalarım") is stored by id.
- Colours and fonts only from `DS`. Article colours: der blue, die red, das green.
- No network, no accounts, no analytics. See `PRIVACY.md`.

## Design tokens (for web / Android)

| Token | Light | Dark |
|---|---|---|
| ground | #F7F7F4 | #0E0F0C |
| surface | #FFFFFF | #1A1B17 |
| ink | #0E0F0C | #F2F2EE |
| muted | #5E615A | #A9ABA3 |
| hairline | #E6E6E0 | #2A2C27 |
| night (feature cards) | #0E0F0C | #23251F |
| gold | #F2C230 | #F2C230 |
| der / die / das | #2F5BEA / #C8323A / #157A41 | #8FA9FF / #FF8A8E / #5FD08A |

Display font: Bricolage Grotesque 700/800. Text font: Geist 400/500/600.

## Later platforms

- **Web**: a static site (for example SvelteKit or React) can load the same `Resources/` files. The question bank (`Core/Engine/QuestionBank.swift`) is the main piece to port; it is pure logic over the JSON.
- **Android**: Kotlin + Compose with the same JSON and tokens. Port `QuestionBank`, `ReadingQuiz` and `GermanNumbers`, or move question generation into `tools/` and ship a generated bank to all platforms.
