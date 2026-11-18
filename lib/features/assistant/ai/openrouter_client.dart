/// A small, non-streaming client for OpenRouter's chat completions API,
/// called directly with a key or through Bloom's hosted proxy.
///
/// Bloom only ever asks for free models. The model is the fixed router
/// [kAiModel], and [assertFreeModel] rejects any other id that doesn't end
/// in `:free`, whatever the endpoint. The client never logs requests,
/// responses, or the key.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_settings.dart';

export 'ai_settings.dart' show AiEndpoint, kOpenRouterUrl;

/// OpenRouter's router that picks an available free model for each request.
const String kAiModel = 'openrouter/free';

/// The default answer budget. Free reasoning models spend 100 to 400
/// tokens on hidden reasoning before they write the answer.
const int kAiMaxTokens = 900;

/// Throws an [ArgumentError] unless [model] is [kAiModel] or a `:free` model.
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
    this.model = kAiModel,
    this.timeout = const Duration(seconds: 45),
  })  : _key = apiKey,
        url = url ?? kOpenRouterUrl,
        _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null {
    assertFreeModel(model);
  }

  /// A client for [endpoint].
  factory OpenRouterClient.to(AiEndpoint endpoint, {http.Client? httpClient}) => OpenRouterClient(
        apiKey: endpoint.apiKey,
        url: endpoint.url,
        viaProxy: endpoint.isProxy,
        httpClient: httpClient,
      );

  final String? _key;
  final Uri url;
  final bool viaProxy;
  final http.Client _http;
  final bool _ownsClient;
  final String model;
  final Duration timeout;

  /// Sends [messages] and returns the first choice's text.
  ///
  /// Throws an [AiException] with a user-facing message on any failure. An
  /// empty answer counts as a failure unless [allowEmpty] is true.
  Future<AiReply> complete(
    List<AiMessage> messages, {
    int maxTokens = kAiMaxTokens,
    double temperature = 0.4,
    bool allowEmpty = false,
  }) async {
    assertFreeModel(model);
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
              'model': model,
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

    if (res.statusCode != 200) throw aiErrorFor(res.statusCode, _errorText(body), viaProxy);
    // OpenRouter can report an upstream failure inside a 200 response.
    final err = body?['error'];
    if (err is Map) {
      final code = err['code'];
      throw aiErrorFor(code is int ? code : 502, _errorText(body), viaProxy);
    }

    final choices = body?['choices'];
    final first = choices is List && choices.isNotEmpty ? choices.first : null;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;
    final text = content is String ? content.trim() : '';
    final answeredBy = body?['model'] is String ? body!['model'] as String : model;
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
    400 => "OpenRouter didn't accept the request. Try rewording your question.",
    401 => "The OpenRouter key isn't valid. Check it in Ask > AI answers.",
    402 => 'OpenRouter says the account needs credits. Free models usually '
        "don't, so check the account's balance on openrouter.ai.",
    403 => "OpenRouter blocked this request because of the key's restrictions, "
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
    429 => 'Free models allow about 20 questions a minute and a daily limit. '
        "Wait a minute and try again, or try tomorrow if you've reached today's limit.",
    >= 500 => 'The free model provider is having trouble. Try again in a moment.',
    _ => 'Something went wrong with the AI answer (error $status). Try again later.',
  };
  return AiException(message, status: status);
}
