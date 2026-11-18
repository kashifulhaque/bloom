/// A small, non-streaming client for OpenRouter's chat completions API,
/// called directly with a key or through Bloom's hosted proxy.
///
/// Bloom only ever asks for free models. Each request names the larger free
/// models in [kAiModels], in order of preference, and [assertFreeModel]
/// rejects any id that doesn't end in `:free`, whatever the endpoint. The
/// client never logs requests, responses, or the key.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_settings.dart';

export 'ai_settings.dart' show AiEndpoint, kOpenRouterUrl;

/// OpenRouter's router that picks any available free model. Bloom doesn't
/// use it by default: it can pick very small models that get health facts
/// wrong. It stays allowed for a client created with an explicit `model`.
const String kAiModel = 'openrouter/free';

/// The free models Bloom asks for, in order of preference. These are the
/// larger general-purpose free models; small, preview, and code models are
/// left out because their health answers are less reliable.
///
/// OpenRouter accepts at most [kMaxModelsPerRequest] models per request and
/// falls back down the list when one is busy. A model id that OpenRouter no
/// longer lists makes it reject the whole request, so [OpenRouterClient]
/// drops that id and asks again. Check the list against
/// https://openrouter.ai/api/v1/models when free models change.
const List<String> kAiModels = [
  'google/gemma-4-31b-it:free',
  'nvidia/nemotron-3-ultra-550b-a55b:free',
  'google/gemma-4-26b-a4b-it:free',
  'nvidia/nemotron-3.5-super-vl:free',
];

/// The most models OpenRouter accepts in one request's `models` list.
const int kMaxModelsPerRequest = 3;

/// The default answer budget. Free reasoning models spend 100 to 400
/// tokens on hidden reasoning before they write the answer.
const int kAiMaxTokens = 900;

/// Throws an [ArgumentError] unless [model] is the free router [kAiModel] or
/// a `:free` model.
void assertFreeModel(String model) {
  if (model == kAiModel || model.endsWith(':free')) return;
  throw ArgumentError.value(model, 'model', 'Bloom only uses free OpenRouter models');
}

/// One chat message: `system`, `user`, or `assistant`.
class AiMessage {
  const AiMessage(this.role, this.content);
  const AiMessage.system(this.content) : role = 'system';
  const AiMessage.user(this.content) : role = 'user';
  const AiMessage.assistant(this.content) : role = 'assistant';

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// An answer and the id of the free model that wrote it.
class AiReply {
  const AiReply(this.text, this.model);
  final String text;

  /// The `model` field of the response, for example
  /// `meta-llama/llama-3.3-70b-instruct:free`.
  final String model;
}

/// A request that failed, with a calm message to show the user.
class AiException implements Exception {
  const AiException(this.message, {this.status});
  final String message;

  /// The HTTP status, or null for network errors and timeouts.
  final int? status;

  @override
  String toString() => 'AiException($status): $message';
}

/// Sends chat requests to OpenRouter with a key, or to Bloom's proxy
/// without one.
class OpenRouterClient {
  /// Sends requests to [url] (OpenRouter by default). With an [apiKey], each
  /// request carries an `Authorization` header; without one, it carries
  /// none. Set [viaProxy] when [url] is Bloom's proxy, for its error
  /// messages.
  OpenRouterClient({
    String? apiKey,
    Uri? url,
    this.viaProxy = false,
    http.Client? httpClient,
    String? model,
    List<String> models = kAiModels,
    this.timeout = const Duration(seconds: 45),
  }) : _key = apiKey,
       url = url ?? kOpenRouterUrl,
       _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       models = List.unmodifiable(model != null ? [model] : models) {
    if (this.models.isEmpty) throw ArgumentError.value(models, 'models', 'must not be empty');
    this.models.forEach(assertFreeModel);
  }

  /// A client for [endpoint].
  factory OpenRouterClient.to(AiEndpoint endpoint, {http.Client? httpClient}) =>
      OpenRouterClient(apiKey: endpoint.apiKey, url: endpoint.url, viaProxy: endpoint.isProxy, httpClient: httpClient);

  final String? _key;
  final Uri url;
  final bool viaProxy;
  final http.Client _http;
  final bool _ownsClient;

  /// The free models to ask for, in order of preference.
  final List<String> models;
  final Duration timeout;

  /// Sends [messages] and returns the first choice's text.
  ///
  /// Throws an [AiException] with a user-facing message on any failure. An
  /// empty answer counts as a failure unless [allowEmpty] is true.
  ///
  /// The request names up to [kMaxModelsPerRequest] of [models], and
  /// OpenRouter falls back down that list. Bloom asks a second time, at
  /// most, in two cases: OpenRouter rejected a model id it no longer lists
  /// (that id is dropped), or none of the named models could answer and
  /// [models] has others left to try. A rate limit from Bloom's proxy is
  /// never retried.
  Future<AiReply> complete(
    List<AiMessage> messages, {
    int maxTokens = kAiMaxTokens,
    double temperature = 0.4,
    bool allowEmpty = false,
  }) async {
    final batch = models.take(kMaxModelsPerRequest).toList();
    try {
      return await _attempt(batch, messages, maxTokens, temperature, allowEmpty);
    } on _AttemptFailed catch (f) {
      final retired = [
        for (final m in batch)
          if (f.detail.contains(m)) m,
      ];
      final List<String> next;
      if (f.status == 400 && retired.isNotEmpty) {
        next = [
          for (final m in models)
            if (!retired.contains(m)) m,
        ];
      } else if (_couldTryOthers(f.status)) {
        next = [
          for (final m in models)
            if (!batch.contains(m)) m,
        ];
      } else {
        next = const [];
      }
      if (next.isEmpty) throw f.error;
      try {
        return await _attempt(next.take(kMaxModelsPerRequest).toList(), messages, maxTokens, temperature, allowEmpty);
      } on _AttemptFailed catch (again) {
        throw again.error;
      }
    }
  }

  bool _couldTryOthers(int? status) => status == 404 || status == 502 || status == 503 || (status == 429 && !viaProxy);

  Future<AiReply> _attempt(
    List<String> batch,
    List<AiMessage> messages,
    int maxTokens,
    double temperature,
    bool allowEmpty,
  ) async {
    batch.forEach(assertFreeModel);
    final http.Response res;
    try {
      res = await _http
          .post(
            url,
            headers: {
              if (_key != null) 'Authorization': 'Bearer $_key',
              'Content-Type': 'application/json',
              'X-Title': 'Bloom',
            },
            body: jsonEncode({
              if (batch.length == 1) 'model': batch.single else 'models': batch,
              'messages': [for (final m in messages) m.toJson()],
              'max_tokens': maxTokens,
              'temperature': temperature,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw aiErrorFor(408, '', viaProxy);
    } catch (_) {
      throw AiException(
        "Bloom couldn't reach ${viaProxy ? "Bloom's AI service" : 'OpenRouter'}. Check your internet "
        'connection and try again. The offline topics still work.',
      );
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      body = null;
    }

    if (res.statusCode != 200) {
      final detail = _errorText(body);
      throw _AttemptFailed(res.statusCode, detail, aiErrorFor(res.statusCode, detail, viaProxy));
    }
    // OpenRouter can report an upstream failure inside a 200 response.
    final err = body?['error'];
    if (err is Map) {
      final code = err['code'] is int ? err['code'] as int : 502;
      final detail = _errorText(body);
      throw _AttemptFailed(code, detail, aiErrorFor(code, detail, viaProxy));
    }

    final choices = body?['choices'];
    final first = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;
    final text = content is String ? content.trim() : '';
    final answeredBy = body?['model'] is String ? body!['model'] as String : batch.first;
    // A reasoning model can spend the whole budget thinking and leave the
    // content null or empty. Asking again usually works.
    if (text.isEmpty && !allowEmpty) throw const AiException(kUnfinishedAnswer);
    return AiReply(text, answeredBy);
  }

  /// Closes the HTTP client if this client created it.
  void close() {
    if (_ownsClient) _http.close();
  }

  static String _errorText(Map<String, dynamic>? body) {
    final err = body?['error'];
    if (err is Map && err['message'] is String) return err['message'] as String;
    return '';
  }
}

/// One attempt's failure, kept with the raw status and detail so
/// [OpenRouterClient.complete] can decide whether to ask again.
class _AttemptFailed implements Exception {
  const _AttemptFailed(this.status, this.detail, this.error);
  final int? status;
  final String detail;
  final AiException error;
}

/// The message for an answer that came back empty.
const String kUnfinishedAnswer = "The free model didn't finish its answer. Try again.";

/// Maps an HTTP [status] and OpenRouter's error [detail] to a calm,
/// user-facing [AiException]. Set [viaProxy] when the request went through
/// Bloom's proxy, whose key the user can't change.
AiException aiErrorFor(int status, [String detail = '', bool viaProxy = false]) {
  final d = detail.toLowerCase();
  final message = switch (status) {
    401 || 402 || 403 when viaProxy =>
      "Bloom's shared AI service can't answer right now. Try again later, or add your own "
          'free OpenRouter key in Ask > AI answers.',
    404 when d.contains('guardrail') && viaProxy =>
      "The restrictions on Bloom's shared AI key blocked the free model. Try again later, or "
          'add your own free OpenRouter key in Ask > AI answers.',
    429 when viaProxy => "Bloom's shared AI is busy. Try again in a minute.",
    400 when d.contains('model id') =>
      "Bloom's preferred free models aren't available on OpenRouter right now. Try again "
          'later, or update Bloom.',
    400 => "OpenRouter didn't accept the request. Try rewording your question.",
    401 => "The OpenRouter key isn't valid. Check it in Ask > AI answers.",
    402 =>
      'OpenRouter says the account needs credits. Free models usually '
          "don't, so check the account's balance on openrouter.ai.",
    403 =>
      "OpenRouter blocked this request because of the key's restrictions, "
          'such as a free-models-only guardrail, or its content checks.',
    404 when d.contains('guardrail') =>
      "Your OpenRouter key's restrictions blocked the free model. In the key's settings on "
          'openrouter.ai, allow free models, then try again.',
    404 when d.contains('no endpoints') =>
      'No free model can take this request right now. In your OpenRouter '
          'privacy settings, allow free model providers, then try again.',
    404 => "OpenRouter couldn't find a free model for this request. Try again later.",
    408 => 'The model took too long to answer. Try again in a moment.',
    413 => 'That question is too long. Shorten it and try again.',
    429 =>
      'Free models allow about 20 questions a minute and a daily limit. '
          "Wait a minute and try again, or try tomorrow if you've reached today's limit.",
    >= 500 => 'The free model provider is having trouble. Try again in a moment.',
    _ => 'Something went wrong with the AI answer (error $status). Try again later.',
  };
  return AiException(message, status: status);
}
