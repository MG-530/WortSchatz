# Project status

## Completed

The source package contains a Persian RTL Flutter interface, local SQLite initialization and persistence, one-by-one learning cards, Leitner review scheduling, vocabulary search, German text-to-speech, source-aware vocabulary metadata, and gender/type color coding. The bundled asset contains 2,637 vocabulary records (1,711 A1 + 926 A2) from the supplied files and the 12 Starten Wir A1 lesson pages.

The data integrity validation passed: all 2,637 records have unique normalized keys, a German display value, and lesson metadata. The Flutter source contains the SQLite schema, TTS configuration, review logic, and all required gender colors.

### Streak Feature
Added streak tracking system:
- `lib/services/streak_service.dart` — tracks current/longest streak using SharedPreferences, records study sessions
- `lib/widgets/streak_chart.dart` — StatelessWidget bar chart showing last 7 days activity, current/longest streak display
- Streak data loaded in `Dashboard.load()` and passed as props to `StreakChart` (no SharedPreferences per rebuild)
- `StreakService.recordStudySession()` called from `_showEndOfReviewDialog` in review_session and `dispose()` in learn_session/practice_page

### Performance Fixes
- Converted `StreakChart` from StatefulWidget to StatelessWidget (no SharedPreferences calls per rebuild)
- Fixed `Colors.grey[300]` → `Colors.grey.shade300` null safety
- Added `answer.dispose()` in practice_page.dart

## Environment note

The sandbox did not contain the Flutter SDK, so a device build could not be executed here. The code and asset files are ready to be placed in a standard Flutter project. Run `flutter create .` in the project directory if platform folders are not already present, then run `flutter pub get` and `flutter run`.

The current asset preserves blank fields when a source did not provide a reliable translation or IPA. The app provides a visible fallback for missing English/Persian text and always provides German TTS through the device engine.

## Important data note

The web vocabulary content belongs to its original publisher. The project includes source attribution and should be used according to the source website's terms and any required permission for redistribution.
