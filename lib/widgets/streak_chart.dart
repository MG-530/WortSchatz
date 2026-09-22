import 'package:flutter/material.dart';
import '../services/streak_service.dart';
import '../screens/streak_page.dart';

/// Weekly streak chart (Saturday → Friday). Counts sit UNDER the bars,
/// future days are dimmed. Tapping opens the full heatmap page.
class StreakChart extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final List<StreakDay> days;

  const StreakChart({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.days,
  });

  @override
  Widget build(BuildContext c) {
    final counts = [for (final d in days) d.count];
    final maxBar = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);
    return Card(
      // Theme-aware (not hardcoded): stays readable in dark mode.
      color: Theme.of(c).colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
            c, MaterialPageRoute(builder: (_) => const StreakPage())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('🔥 $currentStreak روز پشت سر هم',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('طولانی‌ترین: $longestStreak روز',
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final day = i < days.length
                      ? days[i]
                      : StreakDay(
                          DateTime.now().subtract(Duration(days: 6 - i)),
                          0,
                          true);
                  final count = day.count;
                  // Height differs by count; color deepens with it.
                  // The bar area has a fixed height so every row
                  // (count + weekday) sits on the same baseline.
                  final fraction =
                      maxBar > 0 ? (count / maxBar).clamp(0.0, 1.0) : 0.0;
                  final dimmed = day.future;
                  return Opacity(
                    opacity: dimmed ? 0.35 : 1.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 64,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 28,
                              height: count > 0 ? (12 + 52 * fraction) : 6,
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? Colors.deepPurple.withValues(
                                        alpha: 0.25 + 0.75 * fraction)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('$count',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(weekdayFa(day.date),
                            style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
