import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home.dart';

class StartenWirApp extends StatelessWidget {
  const StartenWirApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Starten Wir A1',
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff102a43),
                brightness: Brightness.light),
            textTheme: GoogleFonts.vazirmatnTextTheme()),
        home: const Home(),
      );
}
