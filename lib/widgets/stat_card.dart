import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String t, v;
  final IconData icon;
  const StatCard(this.t, this.v, this.icon, {super.key});

  @override
  Widget build(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Icon(icon, color: Theme.of(c).colorScheme.primary),
            const Spacer(),
            Text(v,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(t)
          ])));
}
