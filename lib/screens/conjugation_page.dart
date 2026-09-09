import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Full conjugation tables of one verb.
///
/// [moods] is a decoded list of
/// {mood, mood_fa, tenses: [{tense, tense_fa, forms: [{p, f, irr}]}]}.
/// Irregular forms are highlighted (bold + red).
class ConjugationPage extends StatelessWidget {
  final String verb;
  final List moods;
  const ConjugationPage({required this.verb, required this.moods, super.key});

  @override
  Widget build(BuildContext c) => Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(title: Text('صرف فعل $verb')),
          body: moods.isEmpty
              ? const Center(child: Text('جدول صرفی یافت نشد'))
              : ListView(children: [
                  const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Text('فرم‌های بی‌قاعده پررنگ و قرمز مشخص شده‌اند',
                          style: TextStyle(color: Colors.grey, fontSize: 13))),
                  for (final m in moods) ...[
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Text('${m['mood']} — ${m['mood_fa']}',
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800))),
                    for (final t in (m['tenses'] as List))
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          child: Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${t['tense']} — ${t['tense_fa']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const Divider(),
                                        Table(
                                            textDirection: ui.TextDirection.ltr,
                                            columnWidths: const {
                                              0: FlexColumnWidth(1),
                                              1: FlexColumnWidth(2)
                                            },
                                            border: TableBorder(
                                                horizontalInside: BorderSide(
                                                    color:
                                                        Colors.grey.shade300)),
                                            children: [
                                              for (final f
                                                  in (t['forms'] as List))
                                                TableRow(children: [
                                                  Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 6),
                                                      child: Text(
                                                          f['p'] as String,
                                                          textDirection: ui
                                                              .TextDirection
                                                              .ltr,
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .grey))),
                                                  Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 6),
                                                      child: Text(
                                                          f['f'] as String,
                                                          textDirection: ui
                                                              .TextDirection
                                                              .ltr,
                                                          textAlign:
                                                              TextAlign.right,
                                                          style: TextStyle(
                                                              fontWeight: (f[
                                                                          'irr'] ==
                                                                      true)
                                                                  ? FontWeight
                                                                      .w800
                                                                  : FontWeight
                                                                      .normal,
                                                              color: (f['irr'] ==
                                                                      true)
                                                                  ? Colors.red
                                                                      .shade700
                                                                  : null))),
                                                ]),
                                            ]),
                                      ]))))
                  ],
                ])));
}
