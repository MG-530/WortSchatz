import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/word.dart';
import '../helpers/colors.dart';
import '../helpers/labels.dart';

class WordCard extends StatelessWidget {
  final Word word;
  final bool revealed;

  const WordCard({required this.word, required this.revealed, super.key});

  @override
  Widget build(BuildContext c) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(
                    label: Text(typeLabel(word)),
                    backgroundColor: wordColor(word).withValues(alpha: .14)),
                const SizedBox(height: 20),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(word.display,
                        textDirection: ui.TextDirection.ltr,
                        maxLines: 2,
                        style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            color: wordColor(word)))),
                const SizedBox(height: 18),
                if (revealed) ...[
                  const Divider(),
                  Text(word.persian,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(word.english)
                ] else
                  const Text('برای نمایش معنی لمس کن',
                      style: TextStyle(color: Colors.grey))
              ])));
}
