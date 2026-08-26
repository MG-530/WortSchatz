# Project status

## Completed

The source package contains a Persian RTL Flutter interface, local SQLite initialization and persistence, one-by-one learning cards, Leitner review scheduling, vocabulary search, German text-to-speech, source-aware vocabulary metadata, and gender/type color coding. The bundled asset contains 1,711 unique vocabulary records from the supplied file and the 12 Starten Wir A1 lesson pages.

The data integrity validation passed: all 1,711 records have unique normalized keys, a German display value, and lesson metadata. The Flutter source contains the SQLite schema, TTS configuration, review logic, and all required gender colors.

## Environment note

The sandbox did not contain the Flutter SDK, so a device build could not be executed here. The code and asset files are ready to be placed in a standard Flutter project. Run `flutter create .` in the project directory if platform folders are not already present, then run `flutter pub get` and `flutter run`.

The current asset preserves blank fields when a source did not provide a reliable translation or IPA. The app provides a visible fallback for missing English/Persian text and always provides German TTS through the device engine.

## Important data note

The web vocabulary content belongs to its original publisher. The project includes source attribution and should be used according to the source website's terms and any required permission for redistribution.
