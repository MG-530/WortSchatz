import '../models/word.dart';

String typeLabel(Word w) => w.gender.isNotEmpty
    ? {
          'masculine': 'مذکر',
          'feminine': 'مونث',
          'neuter': 'خنثی',
          'plural': 'جمع'
        }[w.gender] ??
        w.type
    : {
          'verb': 'فعل',
          'adjective': 'صفت',
          'phrase': 'عبارت',
          'noun': 'اسم'
        }[w.type] ??
        'سایر';
