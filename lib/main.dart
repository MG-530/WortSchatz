import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Friendly Persian fallback instead of the red error screen.
    ErrorWidget.builder = (details) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text('مشکلی پیش آمد',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                              kDebugMode
                                  ? details.exceptionAsString()
                                  : 'لطفاً برنامه را دوباره باز کنید.',
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: Colors.grey)),
                        ])))));

    // sqlite FFI is only needed (and only works) on desktop.
    // On Android/iOS the default sqflite factory is used.
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      databaseFactory = databaseFactoryFfi;
    }

    runApp(const StartenWirApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
