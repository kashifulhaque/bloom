/// Bundled, original educational content: articles and quizzes.
///
/// Article bodies use a tiny markup that `ArticleBody` renders:
/// blank lines separate paragraphs, `## ` starts a subheading, `- ` starts a
/// bullet, and `**text**` is bold.
library;

import 'articles_a.dart';
import 'articles_b.dart';
import 'quizzes.dart';

enum ArticleCategory {
  cycleBasics,
  periodHealth,
  fertility,
  sexRelationships,
  pregnancy,
  afterBirth,
  perimenopause,
  mentalHealth,
  nutritionFitness,
  contraception,
  conditions,
}

extension ArticleCategoryInfo on ArticleCategory {
  String get label => switch (this) {
        ArticleCategory.cycleBasics => 'Cycle basics',
        ArticleCategory.periodHealth => 'Period health',
        ArticleCategory.fertility => 'Fertility & TTC',
        ArticleCategory.sexRelationships => 'Sex & relationships',
        ArticleCategory.pregnancy => 'Pregnancy',
        ArticleCategory.afterBirth => 'After birth',
        ArticleCategory.perimenopause => 'Perimenopause',
        ArticleCategory.mentalHealth => 'Mental health',
        ArticleCategory.nutritionFitness => 'Nutrition & fitness',
        ArticleCategory.contraception => 'Contraception',
        ArticleCategory.conditions => 'Conditions',
      };

  String get emoji => switch (this) {
        ArticleCategory.cycleBasics => '🔄',
        ArticleCategory.periodHealth => '🩸',
        ArticleCategory.fertility => '🌱',
        ArticleCategory.sexRelationships => '💞',
        ArticleCategory.pregnancy => '🤰',
        ArticleCategory.afterBirth => '🍼',
        ArticleCategory.perimenopause => '🌡️',
        ArticleCategory.mentalHealth => '🧠',
        ArticleCategory.nutritionFitness => '🥗',
        ArticleCategory.contraception => '💊',
        ArticleCategory.conditions => '🩺',
      };
}

/// A short educational article.
///
/// [tags] hold phase names (`menstrual`, `follicular`, `ovulation`,
/// `luteal`), goal names (`trackCycle`, `getPregnant`, `trackPregnancy`,
/// `postpartum`, `perimenopause`), and free topic keywords used by search
/// and by the assistant (for example `cramps`, `pms`, `pcos`).
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.category,
    required this.emoji,
    required this.minutes,
    required this.tags,
    required this.body,
  });

  final String id;
  final String title;
  final ArticleCategory category;
  final String emoji;
  final int minutes;
  final List<String> tags;
  final String body;
}

/// One multiple-choice question.
///
/// [correct] is the index of the right option. It's null in couples quizzes,
/// where one partner answers and the other guesses.
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    this.correct,
    required this.explanation,
  });

  final String prompt;
  final List<String> options;
  final int? correct;
  final String explanation;
}

class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.tags,
    required this.questions,
    this.couples = false,
  });

  final String id;
  final String title;
  final String emoji;
  final String description;

  /// Same vocabulary as [Article.tags].
  final List<String> tags;
  final List<QuizQuestion> questions;

  /// Pass-the-phone mode: partner A answers about themself, partner B guesses.
  final bool couples;
}

/// Every bundled article.
final List<Article> kArticles = [...kArticlesA, ...kArticlesB];

/// Every bundled quiz.
const List<Quiz> kQuizzes = kQuizList;

Article? articleById(String id) {
  for (final a in kArticles) {
    if (a.id == id) return a;
  }
  return null;
}

Quiz? quizById(String id) {
  for (final q in kQuizzes) {
    if (q.id == id) return q;
  }
  return null;
}

List<Article> articlesIn(ArticleCategory c) => kArticles.where((a) => a.category == c).toList();

/// Case-insensitive search over titles, tags, and bodies. Title and tag hits
/// rank first.
List<Article> searchArticles(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final words = q.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
  final scored = <(Article, int)>[];
  for (final a in kArticles) {
    var score = 0;
    final title = a.title.toLowerCase();
    final body = a.body.toLowerCase();
    if (title.contains(q)) score += 10;
    for (final w in words) {
      if (title.contains(w)) score += 4;
      if (a.tags.any((t) => t.toLowerCase().contains(w))) score += 3;
      if (a.category.label.toLowerCase().contains(w)) score += 2;
      if (body.contains(w)) score += 1;
    }
    if (score > 0) scored.add((a, score));
  }
  scored.sort((x, y) => y.$2.compareTo(x.$2));
  return [for (final s in scored) s.$1];
}
