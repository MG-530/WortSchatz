import 'package:flutter/material.dart';
import '../models/word.dart';

Color wordColor(Word w) {
  switch (w.gender) {
    case 'masculine':
      return const Color(0xff2979ff);
    case 'feminine':
      return const Color(0xffe85aad);
    case 'neuter':
      return const Color(0xff22a06b);
    case 'plural':
      return const Color(0xffffb300);
  }
  switch (w.type) {
    case 'verb':
      return const Color(0xff7e57c2);
    case 'adjective':
      return const Color(0xffef6c00);
    case 'phrase':
      return const Color(0xff00838f);
    default:
      return const Color(0xff607d8b);
  }
}
