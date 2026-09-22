import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';
import 'settings_service.dart';

/// Text to pronounce: "der Apfel" when [withArticle] is on and the word
/// has an article, otherwise the bare word ("Apfel").
String spokenText(Word w, {required bool withArticle}) {
  final a = w.article.trim();
  if (withArticle && a.isNotEmpty) return '$a ${w.german}';
  return w.german;
}

Future<void> playWord(Word w, {bool? withArticle}) async {
  final speakWithArticle = withArticle ?? await AppSettings.articleTts;
  final text = spokenText(w, withArticle: speakWithArticle);
  final t = FlutterTts();
  try {
    await t.setLanguage('de-DE');
  } catch (_) {
    // Language setting not supported on this platform, proceed anyway
  }
  await t.setSpeechRate(.42);
  await t.speak(text);
}
