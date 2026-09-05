import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/word.dart';
import 'settings_service.dart';

/// Text to pronounce: "der Apfel" when [withArticle] is on and the word
/// has an article, otherwise the bare word ("Apfel").
String spokenText(Word w, {required bool withArticle}) {
  final a = w.article.trim();
  if (withArticle && a.isNotEmpty) return '$a ${w.german}';
  return w.german;
}

Future<void> playWord(Word w, {bool online = false, bool? withArticle}) async {
  final speakWithArticle = withArticle ?? await AppSettings.articleTts;
  final text = spokenText(w, withArticle: speakWithArticle);
  if (online) {
    try {
      final p = AudioPlayer();
      await p.play(UrlSource(
          'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=de&q=${Uri.encodeComponent(text)}'));
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
  await t.speak(text);
}