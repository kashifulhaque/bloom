/// Decides how the Ask screen answers a typed question and builds the AI
/// request.
///
/// Order: crisis and emergency words always get the local safety script.
/// Then, when AI answers are on, consented to, and a source exists (a key,
/// or Bloom's hosted proxy), the question goes to OpenRouter. Otherwise the
/// offline keyword routing answers.
library;

import 'package:http/http.dart' as http;

import '../../../core/store.dart';
import '../scripts.dart';
import 'ai_settings.dart';
import 'cycle_summary.dart';
import 'openrouter_client.dart';
import 'system_prompt.dart';

/// The most earlier free-text turns (questions and AI answers) sent as context.
const int kAiHistoryTurns = 8;

/// One earlier turn sent to the model as context.
class AiTurn {
  const AiTurn({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// How to answer a typed question.
sealed class FreeTextRoute {
  const FreeTextRoute();
}

/// Answer offline with a scripted step.
class LocalRoute extends FreeTextRoute {
  const LocalRoute(this.step, {this.safety = false});
  final BotStep step;

  /// True for the crisis or emergency script.
  final bool safety;
}

/// Answer with the AI model.
class AiRoute extends FreeTextRoute {
  const AiRoute({required this.endpoint, required this.settings});
  final AiEndpoint endpoint;
  final AiSettings settings;
}

/// Picks the route for [text]. Safety words always stay local.
FreeTextRoute routeFreeText(
  String text,
  AppStore store, {
  String buildKey = kBuildTimeKey,
  String proxy = kProxySetting,
}) {
  final safety = safetyStep(text, store);
  if (safety != null) return LocalRoute(safety, safety: true);
  final settings = AiSettings.of(store);
  final endpoint = activeEndpoint(settings, buildKey: buildKey, proxy: proxy);
  if (endpoint == null) return LocalRoute(respondToText(text, store));
  return AiRoute(endpoint: endpoint, settings: settings);
}

/// Builds the messages: the system prompt (with the summary when shared),
/// then the last [kAiHistoryTurns] turns of [history], which ends with the
/// question being asked.
List<AiMessage> buildAiMessages({required List<AiTurn> history, String? summary}) {
  final recent = history.length > kAiHistoryTurns ? history.sublist(history.length - kAiHistoryTurns) : history;
  // Start with a question, so a trimmed history never opens on an answer.
  final start = recent.indexWhere((t) => t.fromUser);
  return [
    AiMessage.system(buildSystemPrompt(summary: summary)),
    for (final t in start < 0 ? const <AiTurn>[] : recent.sublist(start))
      t.fromUser ? AiMessage.user(t.text) : AiMessage.assistant(t.text),
  ];
}

/// Sends [history] to the model with [route]'s endpoint and settings.
Future<AiReply> askAi(
  AiRoute route,
  AppStore store,
  List<AiTurn> history, {
  http.Client? httpClient,
}) async {
  final client = OpenRouterClient.to(route.endpoint, httpClient: httpClient);
  try {
    return await client.complete(buildAiMessages(
      history: history,
      summary: route.settings.shareSummary ? buildCycleSummary(store) : null,
    ));
  } finally {
    client.close();
  }
}

/// The result of [answerFreeText]: a local step, an AI reply, or an error.
class FreeTextAnswer {
  const FreeTextAnswer.local(BotStep this.step)
      : reply = null,
        error = null;
  const FreeTextAnswer.ai(AiReply this.reply)
      : step = null,
        error = null;
  const FreeTextAnswer.error(AiException this.error)
      : step = null,
        reply = null;

  final BotStep? step;
  final AiReply? reply;
  final AiException? error;
}

/// Answers [text] end to end. [history] holds earlier free-text turns,
/// without [text].
Future<FreeTextAnswer> answerFreeText(
  String text,
  AppStore store, {
  List<AiTurn> history = const [],
  http.Client? httpClient,
  String buildKey = kBuildTimeKey,
  String proxy = kProxySetting,
}) async {
  final route = routeFreeText(text, store, buildKey: buildKey, proxy: proxy);
  return switch (route) {
    LocalRoute(:final step) => FreeTextAnswer.local(step),
    AiRoute() => await askAi(route, store, [...history, AiTurn(fromUser: true, text: text)], httpClient: httpClient)
        .then<FreeTextAnswer>(FreeTextAnswer.ai, onError: (Object e) {
      if (e is AiException) return FreeTextAnswer.error(e);
      throw e;
    }),
  };
}

/// A short display name for a model id: no vendor prefix, no `:free`.
String modelDisplayName(String model) {
  var m = model;
  final slash = m.indexOf('/');
  if (slash >= 0) m = m.substring(slash + 1);
  if (m.endsWith(':free')) m = m.substring(0, m.length - 5);
  return m.isEmpty ? model : m;
}
