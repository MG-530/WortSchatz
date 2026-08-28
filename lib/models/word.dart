class Word {
  final int id;
  final String german, display, article, persian, english, pronunciation, type, gender;
  final List<int> lessons;
  final int box;
  final DateTime? nextReview;

  Word({
    required this.id,
    required this.german,
    required this.display,
    required this.article,
    required this.persian,
    required this.english,
    required this.pronunciation,
    required this.type,
    required this.gender,
    required this.lessons,
    required this.box,
    this.nextReview,
  });

  factory Word.fromMap(Map<String, dynamic> m) => Word(
        id: m['id'] as int,
        german: m['german'] ?? '',
        display: m['display'] ?? m['german'] ?? '',
        article: m['article'] ?? '',
        persian: m['persian'] ?? '',
        english: m['english'] ?? '',
        pronunciation: m['pronunciation'] ?? '',
        type: m['word_type'] ?? 'other',
        gender: m['gender'] ?? '',
        lessons: (m['lessons'] as String? ?? '')
            .split(',')
            .where((e) => e.isNotEmpty)
            .map(int.parse)
            .toList(),
        box: m['box'] ?? 0,
        nextReview: m['next_review'] == null
            ? null
            : DateTime.tryParse(m['next_review']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'german': german,
        'display': display,
        'article': article,
        'persian': persian,
        'english': english,
        'pronunciation': pronunciation,
        'word_type': type,
        'gender': gender,
        'lessons': lessons.join(','),
        'box': box,
        'next_review': nextReview?.toIso8601String(),
      };
}
