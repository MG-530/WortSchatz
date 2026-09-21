# WortSchatz

![Android build](https://github.com/MG-530/WortSchatz/actions/workflows/android-build.yml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

A Persian-first German vocabulary trainer built with Flutter, based on the
*Starten Wir* A1/A2 coursebooks. Learn words lesson by lesson, lock them in
with a Leitner spaced-repetition system, and keep a daily study streak.

## Features

- **Lessons (A1/A2)** — browse 12 lessons per level with book covers, add a
  single lesson or the whole book to Leitner
- **Leitner SRS** — boxes 0–5 with scheduled reviews (`0→1d→2d→4d→7d→14d`);
  words enter only through explicit *add* actions, never implicitly
- **Flashcards** — tap-to-reveal cards, German→Persian and reverse
  (Persian→German) modes, swipe + back navigation, noun plurals on answers
- **Article quiz** — multiple-choice `der/die/das` sessions per level or per
  lesson, with animated verdicts
- **Writing & translation practice** — listen-and-type, scrambled letters,
  timed translation with auto-advance
- **Verb conjugations** — 351 full tables (mood × tense × pronoun,
  irregular forms highlighted), opened from any word
- **Pronunciation** — offline TTS with an optional article toggle
  (*der Apfel* vs *Apfel*), online voice fallback, autoplay in lessons
- **Streak & daily goal** — study streak with 7-day chart, configurable
  daily word goal with a progress ring
- **Daily reminder** — local notification at your chosen time showing the
  due-word count (Android/iOS)
- **Backup & restore** — export/import Leitner progress as JSON
- **Persian-first UI** — RTL layout, Vazirmatn font, `fa` locale with
  English/German support

## Data

Vocabulary is bundled as JSON assets, cross-checked against
dic.b-amooz.com (2637 entries: corrected word types, articles, genders):

| Asset | Content |
|---|---|
| `assets/vocab_merged.json` | Words (german, article, gender, type, level, lessons, …) |
| `assets/conjugations.json` | 351 verb tables + aliases |
| `assets/plurals.json` | 906 noun plurals |

On boot the database is seeded from these assets; existing installs get
non-destructive metadata backfills (Leitner progress is never wiped).

### Leitner box model

| Box | Meaning |
|---|---|
| `-1` | Not in Leitner yet (fresh pool, invisible to review) |
| `0` | Entry — added via *add to Leitner*, always due |
| `1–5` | Scheduled progress |

## Getting started

```bash
flutter pub get
flutter run
```

Requirements: Flutter 3.x (see `pubspec.yaml`), Android/iOS/desktop via
`sqflite` / `sqflite_common_ffi` (FFI is enabled on desktop only).

```bash
flutter analyze   # lint (clean: no errors or warnings)
```

## Project layout

```
lib/
  app.dart                 MaterialApp, locale, splash + boot
  main.dart                zoned guard, error fallback, desktop FFI guard
  models/word.dart          Word entity
  services/
    database_service.dart   SQLite: words, conjugations, plurals, Leitner grade()
    streak_service.dart     streak counters + 7-day history
    settings_service.dart   SharedPreferences accessors
    audio_service.dart      TTS / online voice, article-aware
    notification_service.dart  daily reminder scheduling
  screens/
    home.dart               bottom-nav shell + dashboard
    lessons_page.dart       book, lessons, practice/quiz entries
    learn_session.dart      study-only card pager
    review_page.dart        Leitner boxes + session picker
    review_session.dart     flashcards (normal/reverse)
    writing_review.dart     typed answers from letter chips
    practice_page.dart      translation + writing drills
    article_quiz.dart       der/die/das quiz
    conjugation_page.dart   verb tables
    words_page.dart         searchable word list + detail sheet
    settings_page.dart      level, audio, reminder, goal, backup, resets
  widgets/                  header, stat cards, streak chart
```

## Screenshots

_TODO: add screenshots (`fastlane/` or `screenshots/`)._

## License

MIT — see [LICENSE](LICENSE).
