import 'dart:async';
import 'dart:convert';

import 'package:bloom/core/dates.dart';
import 'package:bloom/core/models.dart';
import 'package:bloom/core/store.dart';
import 'package:bloom/features/assistant/ai/ai_chat.dart';
import 'package:bloom/features/assistant/ai/ai_settings.dart';
import 'package:bloom/features/assistant/ai/ai_settings_screen.dart';
import 'package:bloom/features/assistant/ai/cycle_summary.dart';
import 'package:bloom/features/assistant/ai/openrouter_client.dart';
import 'package:bloom/features/assistant/ai/system_prompt.dart';
import 'package:bloom/features/assistant/assistant_screen.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

const _key = 'sk-or-v1-test-0000000000000000';

http.Response _ok(String text, {String model = 'meta-llama/llama-3.3-70b-instruct:free'}) => http.Response(
      jsonEncode({
        'id': 'gen-1',
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

http.Response _err(int status, String message) =>
    http.Response(jsonEncode({'error': {'code': status, 'message': message}}), status);

/// A mock client that records requests and answers with [respond].
class _Recorder {
  _Recorder([http.Response Function(http.Request r)? respond]) {
    client = MockClient((r) async {
      requests.add(r);
      return (respond ?? (_) => _ok('Hello'))(r);
    });
  }
  final requests = <http.Request>[];
  late final MockClient client;
}

AppStore _store({bool ai = true, bool share = false, String? userKey = _key}) {
  final s = AppStore.memory(
    profile: Profile(name: 'Rosalind Quill', birthYear: today().year - 32, onboarded: true),
  );
  s.startPeriod(addDays(today(), -40), length: 5);
  s.startPeriod(addDays(today(), -12), length: 5);
  s.setNote(addDays(today(), -3), 'PRIVATE-NOTE-TEXT');
  s.toggleOption(addDays(today(), -2), 'symptoms', 'cramps');
  s.toggleOption(addDays(today(), -1), 'symptoms', 'cramps');
  s.toggleOption(addDays(today(), -1), 'mood', 'anxious');
  s.toggleOption(addDays(today(), -4), 'sex', 'protected');
  s.setFeature('journal', [
    {'id': 'j1', 'date': dayKey(today()), 'text': 'PRIVATE-JOURNAL-TEXT'},
  ]);
  s.setFeature(kAiFeatureKey, {
    'enabled': ai,
    'shareSummary': share,
    'userKey': userKey,
    'consentAt': ai ? DateTime(2026, 1, 1).toIso8601String() : null,
  });
  return s;
}

void main() {
  group('OpenRouterClient', () {
    test('sends the expected request shape', () async {
      final rec = _Recorder();
      final client = OpenRouterClient(apiKey: _key, httpClient: rec.client);
      final reply = await client.complete(const [AiMessage.system('sys'), AiMessage.user('hi')]);

      expect(reply.text, 'Hello');
      expect(reply.model, 'meta-llama/llama-3.3-70b-instruct:free');
      expect(rec.requests, hasLength(1));
      final r = rec.requests.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
      expect(r.headers['Authorization'], 'Bearer $_key');
      expect(r.headers['Content-Type'], startsWith('application/json'));
      expect(r.headers['X-Title'], 'Bloom');
      expect(r.headers.keys.map((k) => k.toLowerCase()), isNot(contains('http-referer')));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['models'], kAiModels.take(kMaxModelsPerRequest).toList());
      expect(body.containsKey('model'), isFalse);
      expect(body['max_tokens'], 900);
      expect(body['temperature'], 0.4);
      expect(body.containsKey('stream'), isFalse);
      expect(body['messages'], [
        {'role': 'system', 'content': 'sys'},
        {'role': 'user', 'content': 'hi'},
      ]);
    });

    test('never logs the key', () async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
      addTearDown(() => debugPrint = original);

      final ok = OpenRouterClient(apiKey: _key, httpClient: _Recorder().client);
      await ok.complete(const [AiMessage.user('hi')]);
      final bad = OpenRouterClient(apiKey: _key, httpClient: _Recorder((_) => _err(401, 'No auth')).client);
      final e = await bad.complete(const [AiMessage.user('hi')]).then<Object?>((_) => null, onError: (Object e) => e);

      expect(logs.join('\n'), isNot(contains(_key)));
      expect(e.toString(), isNot(contains(_key)));
      expect(AiSettings.fromJson({'userKey': _key}).toString(), isNot(contains(_key)));
    });

    test('guard rejects paid model ids', () {
      expect(() => assertFreeModel('openrouter/free'), returnsNormally);
      expect(() => assertFreeModel('meta-llama/llama-3.3-70b-instruct:free'), returnsNormally);
      for (final paid in ['openai/gpt-4o', 'anthropic/claude-sonnet-4', 'openrouter/auto', 'x/free', '']) {
        expect(() => assertFreeModel(paid), throwsArgumentError, reason: paid);
        expect(() => OpenRouterClient(apiKey: _key, model: paid), throwsArgumentError, reason: paid);
      }
    });

    group('error mapping', () {
      Future<AiException> failWith(http.Response Function(http.Request) respond) async {
        final client = OpenRouterClient(apiKey: _key, httpClient: _Recorder(respond).client);
        try {
          await client.complete(const [AiMessage.user('hi')]);
        } on AiException catch (e) {
          return e;
        }
        throw StateError('expected an AiException');
      }

      final cases = <int, (String, String)>{
        401: ('Invalid key', "isn't valid"),
        402: ('Insufficient credits', 'credits'),
        403: ('Key guardrail', 'restrictions'),
        408: ('Timeout', 'too long'),
        429: ('Rate limited', '20 questions a minute'),
        500: ('Internal', 'having trouble'),
        502: ('Bad gateway', 'having trouble'),
        503: ('Unavailable', 'having trouble'),
      };
      for (final c in cases.entries) {
        test('${c.key}', () async {
          final e = await failWith((_) => _err(c.key, c.value.$1));
          expect(e.status, c.key);
          expect(e.message, contains(c.value.$2));
        });
      }

      test('404 no endpoints points to privacy settings', () async {
        final e = await failWith((_) => _err(404, 'No endpoints found matching your data policy'));
        expect(e.message, contains('privacy settings'));
      });

      test('error inside a 200 response', () async {
        final e = await failWith((_) => http.Response(jsonEncode({'error': {'code': 502, 'message': 'upstream'}}), 200));
        expect(e.message, contains('having trouble'));
      });

      test('empty answer', () async {
        final e = await failWith((_) => _ok(''));
        expect(e.message, "The free model didn't finish its answer. Try again.");
      });

      test('offline', () async {
        final client = OpenRouterClient(
          apiKey: _key,
          httpClient: MockClient((_) async => throw http.ClientException('Failed host lookup')),
        );
        await expectLater(
          client.complete(const [AiMessage.user('hi')]),
          throwsA(isA<AiException>().having((e) => e.message, 'message', contains('internet'))),
        );
      });

      test('client timeout', () async {
        final never = Completer<http.Response>();
        final client = OpenRouterClient(
          apiKey: _key,
          httpClient: MockClient((_) => never.future),
          timeout: const Duration(milliseconds: 10),
        );
        await expectLater(
          client.complete(const [AiMessage.user('hi')]),
          throwsA(isA<AiException>().having((e) => e.status, 'status', 408)),
        );
      });
    });
  });

  group('key and settings', () {
    test('AI answers are off by default', () {
      final s = AiSettings.of(AppStore.memory());
      expect(s.enabled, isFalse);
      expect(s.shareSummary, isFalse);
      expect(activeEndpoint(s, buildKey: 'build-key', proxy: '/api/ai/chat'), isNull);
    });

    test('user key wins over the build-time key', () {
      const withUser = AiSettings(userKey: 'user-key');
      expect(resolveApiKey(withUser, buildKey: 'build-key'), (key: 'user-key', source: KeySource.user));
      expect(resolveApiKey(const AiSettings(), buildKey: 'build-key'), (key: 'build-key', source: KeySource.buildTime));
      expect(resolveApiKey(const AiSettings(), buildKey: '  '), (key: null, source: KeySource.none));
      expect(AiSettings.fromJson({'userKey': '   '}).userKey, isNull);
    });

    test('needs consent and the toggle', () {
      expect(activeEndpoint(const AiSettings(enabled: true, userKey: 'k'), buildKey: '', proxy: ''), isNull);
      expect(activeEndpoint(const AiSettings(enabled: true, userKey: 'k', consentAt: 'x'), buildKey: '', proxy: '')?.apiKey, 'k');
      expect(activeEndpoint(const AiSettings(enabled: false, userKey: 'k', consentAt: 'x'), buildKey: '', proxy: ''), isNull);
    });
  });

  group('cycle summary', () {
    test('has coarse facts and no private data', () {
      final s = _store();
      final text = buildCycleSummary(s);
      expect(text, contains('Goal: Track my cycle'));
      expect(text, contains('Cycle day: 13'));
      expect(text, contains('Average cycle: 28 days'));
      expect(text, contains('cramps (2 days)'));
      expect(text, contains('anxious (1 day)'));
      expect(text, contains('Age: 30-34'));
      for (final secret in [
        'Rosalind',
        'Quill',
        'PRIVATE-NOTE-TEXT',
        'PRIVATE-JOURNAL-TEXT',
        '${today().year - 32}',
        'protected',
        dayKey(addDays(today(), -4)),
        RegExp(r'\d{4}-\d{2}-\d{2}').pattern,
      ]) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
      expect(RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(text), isFalse);
    });

    test('pregnancy week, and age brackets', () {
      final s = AppStore.memory(profile: Profile(goal: Goal.trackPregnancy));
      s.setFeature('pregnancy', {'lmp': dayKey(addDays(today(), -70)), 'babies': 1});
      expect(buildCycleSummary(s), contains('Pregnancy: week 10'));
      expect(ageBracket(30), '30-34');
      expect(ageBracket(34), '30-34');
      expect(ageBracket(19), '15-19');
      expect(ageBracket(12), 'under 15');
    });

    test('is sent only when the toggle is on', () async {
      for (final share in [false, true]) {
        final rec = _Recorder();
        await answerFreeText('What helps with bloating?', _store(share: share), httpClient: rec.client, buildKey: '');
        final body = jsonDecode(rec.requests.single.body) as Map<String, dynamic>;
        final system = (body['messages'] as List).first['content'] as String;
        expect(system.contains('Cycle summary shared'), share, reason: 'share: $share');
        expect(system.contains('Average cycle'), share);
        expect(rec.requests.single.body, isNot(contains('Rosalind')));
        expect(rec.requests.single.body, isNot(contains('PRIVATE-')));
      }
    });
  });

  group('routing', () {
    test('crisis and emergency text never reaches the client', () async {
      final rec = _Recorder();
      final store = _store();
      for (final text in [
        'I want to die',
        'thinking about self-harm',
        "I'm soaking a pad every hour",
        'severe pain and I passed out',
        'is this an emergency?',
      ]) {
        final a = await answerFreeText(text, store, httpClient: rec.client, buildKey: '');
        expect(a.step, isNotNull, reason: text);
        expect(a.step!.id, anyOf('crisis', 'urgent'));
      }
      expect(rec.requests, isEmpty);
    });

    test('AI off falls back to keyword routing', () async {
      final rec = _Recorder();
      final a = await answerFreeText('my cramps are bad', _store(ai: false), httpClient: rec.client, buildKey: 'build');
      expect(a.step?.id, 'pain');
      expect(rec.requests, isEmpty);
    });

    test('AI on without a key falls back to keyword routing', () async {
      final rec = _Recorder();
      final a = await answerFreeText('my cramps are bad', _store(userKey: null), httpClient: rec.client, buildKey: '');
      expect(a.step?.id, 'pain');
      expect(rec.requests, isEmpty);
    });

    test('AI on sends the system prompt and the recent turns', () async {
      final rec = _Recorder((_) => _ok('Cramps often ease with heat.'));
      final history = [
        for (var i = 0; i < 12; i++) AiTurn(fromUser: i.isEven, text: 'turn $i'),
      ];
      final a = await answerFreeText('my cramps are bad', _store(), history: history, httpClient: rec.client, buildKey: '');
      expect(a.reply?.text, 'Cramps often ease with heat.');
      final msgs = (jsonDecode(rec.requests.single.body)['messages'] as List).cast<Map>();
      expect(msgs.first['role'], 'system');
      expect(msgs.first['content'], kSystemPrompt.trim());
      expect(msgs.last, {'role': 'user', 'content': 'my cramps are bad'});
      expect(msgs.length - 1, lessThanOrEqualTo(kAiHistoryTurns));
      expect(msgs[1]['role'], 'user');
    });

    test('AI errors come back as calm messages', () async {
      final rec = _Recorder((_) => _err(429, 'Rate limit exceeded: free-models-per-min'));
      final a = await answerFreeText('what is the luteal phase?', _store(), httpClient: rec.client, buildKey: '');
      expect(a.error?.status, 429);
    });

    test('model display name', () {
      expect(modelDisplayName('meta-llama/llama-3.3-70b-instruct:free'), 'llama-3.3-70b-instruct');
      expect(modelDisplayName('openrouter/free'), 'free');
    });
  });

  group('widgets', () {
    Widget wrap(AppStore store, Widget child) => ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
        );

    testWidgets('Ask shows an AI reply with a caption', (tester) async {
      final rec = _Recorder((_) => _ok('**Heat** can help.\n- Rest\n- Water'));
      final store = _store();
      await tester.pumpWidget(wrap(store, AssistantScreen(httpClient: rec.client)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'what helps period cramps?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(rec.requests, hasLength(1));
      expect(find.textContaining('may be wrong'), findsOneWidget);
      expect(find.textContaining('llama-3.3-70b-instruct'), findsOneWidget);
      final saved = (store.feature<Map>('assistant')!['messages'] as List).cast<Map>();
      expect(saved.last['ai'], isTrue);
      expect(saved.last['model'], 'meta-llama/llama-3.3-70b-instruct:free');
    });

    testWidgets('Ask keeps crisis text local and offers retry on errors', (tester) async {
      final rec = _Recorder((_) => _err(503, 'down'));
      await tester.pumpWidget(wrap(_store(), AssistantScreen(httpClient: rec.client)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'I want to hurt myself');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(rec.requests, isEmpty);

      await tester.enterText(find.byType(TextField), 'what is ovulation?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      // A 503 for the first three models makes the client try the remaining
      // preferred model once, so each question sends two requests.
      expect(rec.requests, hasLength(2));
      expect(find.textContaining('having trouble'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(rec.requests, hasLength(4));
      final sent = jsonDecode(rec.requests.last.body)['messages'] as List;
      expect(jsonEncode(sent), isNot(contains('hurt myself')));
    });

    testWidgets('settings: consent on first enable, and the key is never shown', (tester) async {
      final store = AppStore.memory();
      AiSettings.fromJson({'userKey': _key}).save(store);
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(store, const AiSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining(_key), findsNothing);
      expect(find.textContaining('Using your own OpenRouter key'), findsWidgets);
      expect(find.byKey(const ValueKey('ai-summary-preview')), findsOneWidget);

      await tester.tap(find.text('AI answers').last);
      await tester.pumpAndSettle();
      expect(find.text('AI answers use the internet'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      final s = AiSettings.of(store);
      expect(s.enabled, isTrue);
      expect(s.consentAt, isNotNull);
      expect(s.shareSummary, isFalse);
    });

    testWidgets('settings: test connection reports the model', (tester) async {
      final rec = _Recorder((_) => _ok('ready', model: 'google/gemma-3-27b-it:free'));
      final store = AppStore.memory();
      AiSettings.fromJson({'userKey': _key}).save(store);
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(store, AiSettingsScreen(httpClient: rec.client)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      expect(find.textContaining('gemma-3-27b-it answered'), findsOneWidget);
      expect(jsonDecode(rec.requests.single.body)['models'], kAiModels.take(kMaxModelsPerRequest).toList());
    });
  });

  group('proxy', () {
    const proxyAbs = 'https://bloom.ifkash.dev/api/ai/chat';
    final page = Uri.parse('https://bloom.ifkash.dev/some/route?x=1#frag');

    test('resolution order: user key, build-time key, proxy, none', () {
      const user = AiSettings(userKey: 'user-key');
      const none = AiSettings();
      var e = resolveAiEndpoint(user, buildKey: 'build-key', proxy: proxyAbs)!;
      expect((e.source, e.apiKey, e.url), (KeySource.user, 'user-key', kOpenRouterUrl));
      e = resolveAiEndpoint(none, buildKey: 'build-key', proxy: proxyAbs)!;
      expect((e.source, e.apiKey, e.url), (KeySource.buildTime, 'build-key', kOpenRouterUrl));
      e = resolveAiEndpoint(none, buildKey: ' ', proxy: proxyAbs)!;
      expect((e.source, e.apiKey, e.url.toString()), (KeySource.proxy, null, proxyAbs));
      expect(resolveAiEndpoint(none, buildKey: '', proxy: ''), isNull);
      expect(aiSource(none, buildKey: '', proxy: ''), KeySource.none);
    });

    test('relative proxy resolves against the page origin', () {
      expect(resolveProxyUrl('/api/ai/chat', base: page).toString(), proxyAbs);
      expect(resolveProxyUrl(' $proxyAbs ', base: page).toString(), proxyAbs);
      expect(resolveProxyUrl('https://other.example.com/x', base: page).toString(), 'https://other.example.com/x');
      expect(resolveProxyUrl('', base: page), isNull);
      // A relative path means nothing without a web origin.
      expect(resolveProxyUrl('/api/ai/chat', base: Uri.parse('file:///app/')), isNull);
      expect(resolveProxyUrl('ftp://bloom.ifkash.dev/x', base: page), isNull);
      final rel = resolveAiEndpoint(const AiSettings(), buildKey: '', proxy: '/api/ai/chat', base: page)!;
      expect(rel.url.toString(), proxyAbs);
      expect(rel.isProxy, isTrue);
    });

    test('proxy requests carry no Authorization header and keep the free model', () async {
      final rec = _Recorder();
      final a = await answerFreeText('what is the luteal phase?', _store(userKey: null),
          httpClient: rec.client, buildKey: '', proxy: proxyAbs);
      expect(a.reply?.text, 'Hello');
      final r = rec.requests.single;
      expect(r.url.toString(), proxyAbs);
      expect(r.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['models'], kAiModels.take(kMaxModelsPerRequest).toList());
      expect(body.containsKey('model'), isFalse);
      expect(body['max_tokens'], 900);
    });

    test('a saved key goes straight to OpenRouter even with a proxy', () async {
      final rec = _Recorder();
      await answerFreeText('what is ovulation?', _store(), httpClient: rec.client, buildKey: '', proxy: proxyAbs);
      expect(rec.requests.single.url, kOpenRouterUrl);
      expect(rec.requests.single.headers['Authorization'], 'Bearer $_key');
    });

    test('model guard applies to the proxy too', () {
      for (final paid in ['openai/gpt-4o', 'openrouter/auto']) {
        expect(() => OpenRouterClient(url: Uri.parse(proxyAbs), viaProxy: true, model: paid), throwsArgumentError);
      }
    });

    Future<AiException> fail(http.Response Function(http.Request) respond, {bool viaProxy = true}) async {
      final client = viaProxy
          ? OpenRouterClient(url: Uri.parse(proxyAbs), viaProxy: true, httpClient: _Recorder(respond).client)
          : OpenRouterClient(apiKey: _key, httpClient: _Recorder(respond).client);
      try {
        await client.complete(const [AiMessage.user('hi')]);
      } on AiException catch (e) {
        return e;
      }
      throw StateError('expected an AiException');
    }

    test('429 from the proxy says the shared AI is busy', () async {
      final e = await fail((_) => http.Response('{"error":"rate limited"}', 429));
      expect(e.status, 429);
      expect(e.message, "Bloom's shared AI is busy. Try again in a minute.");
    });

    test('413 says the question is too long', () async {
      for (final viaProxy in [true, false]) {
        final e = await fail((_) => http.Response('Payload Too Large', 413), viaProxy: viaProxy);
        expect(e.message, contains('too long'), reason: 'viaProxy: $viaProxy');
      }
    });

    test('guardrail 404 blames the key restrictions, not privacy settings', () async {
      const detail = 'No endpoints available matching your guardrail restrictions and data policy.';
      final direct = await fail((_) => _err(404, detail), viaProxy: false);
      expect(direct.message, contains("key's restrictions blocked the free model"));
      expect(direct.message, isNot(contains('privacy settings')));
      final viaProxy = await fail((_) => _err(404, detail));
      expect(viaProxy.message, contains('restrictions'));
      expect(viaProxy.message, isNot(contains('privacy settings')));
    });

    test('null or empty content is a recoverable "didn\'t finish" error', () async {
      for (final content in [null, '', '   ']) {
        final e = await fail((_) => http.Response(
              jsonEncode({
                'model': 'some/reasoner:free',
                'choices': [
                  {
                    'message': {'role': 'assistant', 'content': content, 'reasoning': 'Thinking...'},
                    'finish_reason': 'length',
                  },
                ],
              }),
              200,
            ));
        expect(e.message, kUnfinishedAnswer, reason: '$content');
      }
    });

    testWidgets('settings name the proxy and the consent text names its host', (tester) async {
      final rec = _Recorder((_) => _ok('ready', model: 'google/gemma-3-27b-it:free'));
      final store = AppStore.memory();
      await tester.binding.setSurfaceSize(const Size(800, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: AiSettingsScreen(httpClient: rec.client, buildKey: '', proxy: proxyAbs),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining("Using Bloom's shared free AI service"), findsOneWidget);

      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      expect(rec.requests.single.url.toString(), proxyAbs);
      expect(rec.requests.single.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      expect(find.textContaining('gemma-3-27b-it answered'), findsOneWidget);

      await tester.tap(find.text('AI answers').last);
      await tester.pumpAndSettle();
      expect(find.textContaining("Bloom's AI service at bloom.ifkash.dev, then to OpenRouter"), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(AiSettings.of(store).enabled, isTrue);
    });
  });
}
