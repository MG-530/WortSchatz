import 'package:flutter/material.dart';

class StreakChart extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final List<int> days;

  const StreakChart({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.days,
  });

  @override
  Widget build(BuildContext c) {
    final maxBar = days.isEmpty ? 0 : days.reduce((a, b) => a > b ? a : b);
    return Card(
      color: const Color(0xfff0ecff),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('🔥 $currentStreak روز پشت سر هم',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('طولانی‌ترین: $longestStreak روز',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final count = i < days.length ? days[i] : 0;
                final height = maxBar > 0
                    ? (count / maxBar).clamp(0.1, 1.0)
                    : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 60 * height,
                      decoration: BoxDecoration(
                        color: count > 0
                            ? Colors.deepPurple
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: count > 0
                          ? Center(
                              child: Text('$count',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white)))
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه'][i],
                        style: const TextStyle(fontSize: 10)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
