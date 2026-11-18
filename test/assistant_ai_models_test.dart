// Tests for how Bloom picks free models: an ordered list of larger free
// models, at most three per request, with one retry when OpenRouter rejects a
// retired model id or none of the named models can answer.
import 'dart:convert';

import 'package:bloom/features/assistant/ai/openrouter_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _ok(String text, String model) => http.Response(
  jsonEncode({
    'model': model,
    'choices': [
      {
        'message': {'role': 'assistant', 'content': text},
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _err(int status, String message) => http.Response(
  jsonEncode({
    'error': {'code': status, 'message': message},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

/// A mock client that answers each request with the next response in
/// [responses] and records the decoded request bodies.
({http.Client client, List<Map<String, dynamic>> bodies}) _script(List<http.Response> responses) {
  final bodies = <Map<String, dynamic>>[];
  var i = 0;
  final client = MockClient((req) async {
    bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
    return responses[i++];
  });
  return (client: client, bodies: bodies);
}

const _msgs = [AiMessage.user('What is the follicular phase?')];

void main() {
  test('the preferred list holds only larger free models', () {
    expect(kAiModels, isNotEmpty);
    for (final m in kAiModels) {
      expect(m, endsWith(':free'));
      expect(() => assertFreeModel(m), returnsNormally);
    }
    expect(kAiModels, isNot(contains(kAiModel)), reason: 'the router can pick very small models');
    expect(kAiModels.where((m) => m.contains('1.7b')), isEmpty);
  });

  test('a request names the first three preferred models', () async {
    final s = _script([_ok('Answer', kAiModels[1])]);
    final reply = await OpenRouterClient(apiKey: 'k', httpClient: s.client).complete(_msgs);
    expect(reply.text, 'Answer');
    expect(reply.model, kAiModels[1]);
    expect(s.bodies.single['models'], kAiModels.take(kMaxModelsPerRequest).toList());
    expect(s.bodies.single.containsKey('model'), isFalse);
  });

  test('a retired model id is dropped and the request is sent again', () async {
    final retired = kAiModels[0];
    final s = _script([_err(400, '$retired is not a valid model ID'), _ok('Answer', kAiModels[1])]);
    final reply = await OpenRouterClient(apiKey: 'k', httpClient: s.client).complete(_msgs);
    expect(reply.text, 'Answer');
    expect(s.bodies, hasLength(2));
    final second = (s.bodies[1]['models'] as List).cast<String>();
    expect(second, isNot(contains(retired)));
    expect(second, kAiModels.where((m) => m != retired).take(kMaxModelsPerRequest).toList());
  });

  test('when none of the named models can answer, the rest are tried once', () async {
    final s = _script([_err(404, 'No endpoints found'), _ok('Answer', kAiModels.last)]);
    final reply = await OpenRouterClient(apiKey: 'k', httpClient: s.client).complete(_msgs);
    expect(reply.text, 'Answer');
    expect(s.bodies, hasLength(2));
    final second = s.bodies[1];
    final named = second['models'] ?? [second['model']];
    expect(named, kAiModels.skip(kMaxModelsPerRequest).toList());
  });

  test('it asks at most twice', () async {
    final s = _script([_err(404, 'No endpoints found'), _err(404, 'No endpoints found')]);
    final client = OpenRouterClient(apiKey: 'k', httpClient: s.client);
    await expectLater(client.complete(_msgs), throwsA(isA<AiException>().having((e) => e.status, 'status', 404)));
    expect(s.bodies, hasLength(2));
  });

  test("the proxy's own rate limit is never retried", () async {
    final s = _script([_err(429, 'Too many requests')]);
    final client = OpenRouterClient(
      url: Uri.parse('https://bloom.ifkash.dev/api/ai/chat'),
      viaProxy: true,
      httpClient: s.client,
    );
    await expectLater(
      client.complete(_msgs),
      throwsA(isA<AiException>().having((e) => e.message, 'message', contains('busy'))),
    );
    expect(s.bodies, hasLength(1));
  });

  test('a bad request that names no model is not retried', () async {
    final s = _script([_err(400, 'messages must not be empty')]);
    final client = OpenRouterClient(apiKey: 'k', httpClient: s.client);
    await expectLater(client.complete(_msgs), throwsA(isA<AiException>()));
    expect(s.bodies, hasLength(1));
  });

  test('when every preferred model is retired, the message says so', () async {
    final s = _script([
      _err(400, '${kAiModels[0]} is not a valid model ID'),
      _err(400, '${kAiModels[1]} is not a valid model ID'),
    ]);
    final client = OpenRouterClient(apiKey: 'k', httpClient: s.client);
    await expectLater(
      client.complete(_msgs),
      throwsA(isA<AiException>().having((e) => e.message, 'message', contains("aren't available"))),
    );
  });

  test('an explicit single model is sent as model, not models', () async {
    final s = _script([_ok('Answer', 'google/gemma-4-31b-it:free')]);
    await OpenRouterClient(apiKey: 'k', model: 'google/gemma-4-31b-it:free', httpClient: s.client).complete(_msgs);
    expect(s.bodies.single['model'], 'google/gemma-4-31b-it:free');
    expect(s.bodies.single.containsKey('models'), isFalse);
  });

  test('every model in a custom list must be free', () {
    expect(
      () => OpenRouterClient(apiKey: 'k', models: const ['google/gemma-4-31b-it:free', 'openai/gpt-4o']),
      throwsArgumentError,
    );
    expect(() => OpenRouterClient(apiKey: 'k', models: const []), throwsArgumentError);
  });
}
