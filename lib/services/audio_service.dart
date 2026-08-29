import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/word.dart';

Future<void> playWord(Word w, {bool online = false}) async {
  if (online) {
    try {
      final p = AudioPlayer();
      await p.play(UrlSource(
          'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=de&q=${Uri.encodeComponent(w.german)}'));
      return;
    } catch (_) {}
  }
  final t = FlutterTts();
  try {
    await t.setLanguage('de-DE');
  } catch (_) {
    // Language setting not supported on this platform, proceed anyway
  }
  await t.setSpeechRate(.42);
  await t.speak(w.german);
}