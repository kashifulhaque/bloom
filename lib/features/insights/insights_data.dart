/// Reads and writes the `insights` and `journal` feature data.
///
/// `insights` layout:
/// `{bookmarks: [id], read: [id], quizzes: {quizId: {score, total, date}},
/// seenDay: 'yyyy-MM-dd', seen: [cardId]}`.
///
/// `journal` layout: a list of `{id, date, mood, prompt, text}` maps,
/// newest first.
library;

import '../../core/dates.dart';
import '../../core/store.dart';

abstract final class InsightsData {
  static Map<String, dynamic> _get(AppStore s) {
    final raw = s.feature<Map>('insights');
    return raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw);
  }

  static Set<String> _set(AppStore s, String key) =>
      Set<String>.from((_get(s)[key] as List?) ?? const []);

  static void _put(AppStore s, String key, Object value) {
    final m = _get(s)..[key] = value;
    s.setFeature('insights', m);
  }

  // Bookmarks.
  static Set<String> bookmarks(AppStore s) => _set(s, 'bookmarks');
  static bool isBookmarked(AppStore s, String id) => bookmarks(s).contains(id);
  static void toggleBookmark(AppStore s, String id) {
    final b = bookmarks(s);
    b.contains(id) ? b.remove(id) : b.add(id);
    _put(s, 'bookmarks', b.toList());
  }

  // Read state.
  static Set<String> readIds(AppStore s) => _set(s, 'read');
  static bool isRead(AppStore s, String id) => readIds(s).contains(id);
  static void setRead(AppStore s, String id, bool read) {
    final r = readIds(s);
    read ? r.add(id) : r.remove(id);
    _put(s, 'read', r.toList());
  }

  // Quiz results.
  static Map<String, dynamic>? quizResult(AppStore s, String quizId) {
    final q = _get(s)['quizzes'] as Map?;
    final r = q?[quizId];
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }

  static void saveQuizResult(AppStore s, String quizId, int score, int total) {
    final q = Map<String, dynamic>.from((_get(s)['quizzes'] as Map?) ?? const {});
    q[quizId] = {'score': score, 'total': total, 'date': dayKey(DateTime.now())};
    _put(s, 'quizzes', q);
  }

  // Story seen state, kept for the current day only.
  static Set<String> seenToday(AppStore s) {
    final m = _get(s);
    if (m['seenDay'] != dayKey(today())) return {};
    return Set<String>.from((m['seen'] as List?) ?? const []);
  }

  static void markSeen(AppStore s, String cardId) {
    final seen = seenToday(s);
    if (seen.contains(cardId)) return;
    seen.add(cardId);
    final m = _get(s)
      ..['seenDay'] = dayKey(today())
      ..['seen'] = seen.toList();
    s.setFeature('insights', m);
  }
}

/// One private journal entry.
class JournalEntry {
  JournalEntry({
    required this.id,
    required this.date,
    required this.mood,
    required this.prompt,
    required this.text,
  });

  final String id;
  final DateTime date;
  final String mood;
  final String prompt;
  final String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dayKey(date),
        'mood': mood,
        'prompt': prompt,
        'text': text,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as String? ?? '',
        date: parseDayKey(j['date'] as String? ?? dayKey(today())),
        mood: j['mood'] as String? ?? '🙂',
        prompt: j['prompt'] as String? ?? '',
        text: j['text'] as String? ?? '',
      );
}

abstract final class JournalData {
  static List<JournalEntry> entries(AppStore s) {
    final raw = s.feature<List>('journal') ?? const [];
    final list = [
      for (final e in raw) JournalEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Adds [e], or replaces the entry with the same id.
  static void save(AppStore s, JournalEntry e) {
    final list = entries(s).where((x) => x.id != e.id).toList()..add(e);
    list.sort((a, b) => b.date.compareTo(a.date));
    s.setFeature('journal', [for (final x in list) x.toJson()]);
  }

  static void delete(AppStore s, String id) {
    s.setFeature('journal', [
      for (final x in entries(s))
        if (x.id != id) x.toJson(),
    ]);
  }
}

/// Reflective prompts for the journal.
const List<String> kJournalPrompts = [
  'How does my body feel today, from head to toe?',
  'What drained my energy today, and what gave some back?',
  'One thing I want to be gentler with myself about:',
  'What do I need more of this week?',
  'Something small that made me smile today:',
  'How did my mood shift across the day?',
  'What would I tell a friend who felt the way I feel right now?',
  'Which boundary do I want to protect this week?',
  'Three things I am grateful for today:',
  'What did I notice about my cycle or symptoms lately?',
  'A worry I can let go of, and a worry I can act on:',
  'What does rest look like for me right now?',
  'Free write: whatever is on my mind.',
];

const List<String> kJournalMoods = ['😊', '😌', '🙂', '😐', '😔', '😢', '😤', '😰', '🥰', '😴'];
