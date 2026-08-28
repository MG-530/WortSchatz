import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final String title, subtitle;
  const Header(this.title, {this.subtitle = '', super.key});

  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(c)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600))
      ]));
}
