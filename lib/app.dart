import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

class StartenWirApp extends StatelessWidget {
  const StartenWirApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WortSchatz',
        locale: const Locale('fa'),
        supportedLocales: const [
          Locale('fa'),
          Locale('en'),
          Locale('de'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff102a43),
                brightness: Brightness.light),
            textTheme: GoogleFonts.vazirmatnTextTheme()),
        home: const SplashScreen(),
      );
}

/// Shows a splash while the vocabulary database is being prepared,
/// then navigates to Home. DB failures surface as a retryable error
/// screen instead of a black screen / silent crash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> {
  String? error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => error = null);
    try {
      await VocabularyDb.instance.init();
      await NotifyService.init();
      await NotifyService.scheduleDailyReminder();
    } catch (e) {
      debugPrint('DB init failed: $e');
      if (mounted) setState(() => error = e.toString());
      return;
    }
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const Home()));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: error == null
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          Image.asset('assets/logo.png', width: 96, height: 96),
                          const SizedBox(height: 16),
                          const Text('WortSchatz',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text('در حال آماده‌سازی واژه‌ها…',
                              style: TextStyle(color: Colors.grey))
                        ])
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.error_outline,
                              size: 72, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('خطا در آماده‌سازی دیتابیس',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                              onPressed: _boot,
                              icon: const Icon(Icons.refresh),
                              label: const Text('تلاش مجدد'))
                        ])))));
}
