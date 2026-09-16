import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home.dart';

/// First-launch tutorial: 3 swipeable slides explaining the core loop.
/// Shown once (flagged in prefs); "شروع" (or Skip) leads to Home.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingState();
}

class _OnboardingState extends State<OnboardingPage> {
  final _ctl = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.add_task,
      title: 'به لایتنر اضافه کن',
      body:
          'از تب درس‌ها یک درس یا کل کتاب را به لایتنر اضافه کن تا مرور شروع شود.'
    ),
    (
      icon: Icons.inventory_2,
      title: 'هر روز مرور کن',
      body:
          'واژه‌های آماده طبق زمان‌بندی می‌آیند؛ با «بلد بودم» باکس‌ها جلو می‌روند.'
    ),
    (
      icon: Icons.local_fire_department,
      title: 'استریک را حفظ کن',
      body: 'هر روز چند واژه بخوان تا زنجیره روزهای متوالی نپرد.'
    ),
  ];

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('seenOnboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const Home()));
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(automaticallyImplyLeading: false, actions: [
            TextButton(onPressed: _finish, child: const Text('رد شدن'))
          ]),
          body: Column(children: [
            Expanded(
                child: PageView.builder(
                    controller: _ctl,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (c, i) {
                      final s = _slides[i];
                      return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(s.icon,
                                    size: 96,
                                    color: Theme.of(c).colorScheme.primary),
                                const SizedBox(height: 32),
                                Text(s.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 16),
                                Text(s.body,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.grey))
                              ]));
                    })),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < _slides.length; i++)
                Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? Theme.of(c).colorScheme.primary
                            : Colors.grey.shade400))
            ]),
            Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () {
                          if (_page + 1 >= _slides.length) {
                            _finish();
                          } else {
                            _ctl.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          }
                        },
                        child: Text(
                            _page + 1 >= _slides.length ? 'شروع' : 'بعدی'))))
          ])));
}
