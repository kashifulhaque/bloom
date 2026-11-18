// Report share links: encryption, the link format, the saved list, expiry,
// revocation, the HTTP client, and the screen.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloom/core/store.dart';
import 'package:bloom/core/sync/crypto/sync_crypto.dart';
import 'package:bloom/features/reports/doctor_report_screen.dart';
import 'package:bloom/features/reports/share/share_api.dart';
import 'package:bloom/features/reports/share/share_crypto.dart';
import 'package:bloom/features/reports/share/share_link.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n% test report\n${'x' * 1200}\n%%EOF\n'));

/// An in-memory share service with the server's rules: expiry, revocation by
/// token, and 404 for anything gone.
class FakeShareServer implements ReportShareApi {
  FakeShareServer({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  DateTime Function() clock;
  final boxes = <String, ({Uint8List box, String token, DateTime expires})>{};
  final revoked = <String>[];
  var _next = 0;

  @override
  Uri get endpoint => Uri.parse('https://bloom.example.com/api/share');

  @override
  Future<CreatedShare> create(Uint8List box, ShareExpiry expiry) async {
    final id = 'id${_next++}'.padRight(22, 'A');
    final token = 'tok$_next'.padRight(43, 'B');
    final expires = clock().add(Duration(days: expiry.days));
    boxes[id] = (box: box, token: token, expires: expires);
    return CreatedShare(id: id, revokeToken: token, expiresAt: expires);
  }

  @override
  Future<Uint8List> fetch(String id) async {
    final b = boxes[id];
    if (b == null || !b.expires.isAfter(clock())) {
      throw const ShareApiException('This link has expired or was turned off.', status: 404);
    }
    return b.box;
  }

  @override
  Future<void> revoke(String id, String revokeToken) async {
    if (boxes[id]?.token == revokeToken) {
      boxes.remove(id);
      revoked.add(id);
    }
  }
}

/// What the viewer does with a link: fetch by id, decrypt with the fragment.
Future<Uint8List> openLink(ReportShareApi api, String link) async {
  final uri = Uri.parse(link);
  final id = uri.pathSegments.last;
  return ReportShareCrypto.open(await api.fetch(id), ReportShareCrypto.decodeKey(uri.fragment));
}

void main() {
  group('encryption', () {
    test('round trip with a fresh key each time', () async {
      final a = await ReportShareCrypto.seal(_pdf);
      final b = await ReportShareCrypto.seal(_pdf);
      expect(a.key, isNot(b.key));
      expect(a.box.length, _pdf.length + SyncCrypto.overhead);
      expect(a.box[0], SyncCrypto.format);
      expect(await ReportShareCrypto.open(a.box, a.key), _pdf);
    });

    test('refuses a wrong key or a changed box', () async {
      final s = await ReportShareCrypto.seal(_pdf);
      final wrong = Uint8List.fromList(s.key)..[0] ^= 1;
      await expectLater(ReportShareCrypto.open(s.box, wrong), throwsA(isA<SyncCryptoException>()));
      final changed = Uint8List.fromList(s.box)..[40] ^= 1;
      await expectLater(ReportShareCrypto.open(changed, s.key), throwsA(isA<SyncCryptoException>()));
    });

    test('a box sealed for another purpose doesn\'t open as a report', () async {
      final key = SyncCrypto.newDataKey();
      final other = await SyncCrypto.sealWithKey(key, _pdf, utf8.encode('bloom/v1/data-key'));
      await expectLater(ReportShareCrypto.open(other, key), throwsA(isA<SyncCryptoException>()));
    });

    test('key encoding round trips and rejects bad input', () {
      final key = SyncCrypto.newDataKey();
      final text = ReportShareCrypto.encodeKey(key);
      expect(text, hasLength(43));
      expect(text, isNot(contains('=')));
      expect(ReportShareCrypto.decodeKey(text), key);
      expect(() => ReportShareCrypto.decodeKey('short'), throwsFormatException);
      expect(() => ReportShareCrypto.decodeKey('$text='), throwsFormatException);
    });

    test('opens the shared test vector that the viewer test also opens', () async {
      final v = jsonDecode(File('test/fixtures/report_share_vector.json').readAsStringSync()) as Map;
      final out = await ReportShareCrypto.open(
        base64.decode(v['box'] as String),
        ReportShareCrypto.decodeKey(v['key'] as String),
      );
      expect(out, base64.decode(v['plaintext'] as String));
    });
  });

  group('links', () {
    test('the key is in the fragment, on the service\'s origin', () {
      final link = buildShareLink(Uri.parse('https://bloom.example.com/api/share'), 'abc', 'KEY');
      expect(link.toString(), 'https://bloom.example.com/r/abc#KEY');
      final local = buildShareLink(Uri.parse('http://localhost:8080/api/share'), 'abc', 'KEY');
      expect(local.toString(), 'http://localhost:8080/r/abc#KEY');
    });

    test('the build setting resolves relative paths on the web origin', () {
      expect(resolveShareApi(''), isNull);
      expect(
        resolveShareApi('/api/share', Uri.parse('https://bloom.example.com/today')).toString(),
        'https://bloom.example.com/api/share',
      );
      expect(resolveShareApi('https://bloom.example.com/api/share').toString(), 'https://bloom.example.com/api/share');
    });
  });

  group('sharer', () {
    late DateTime now;
    late FakeShareServer server;
    late ReportSharer sharer;
    late AppStore store;

    setUp(() {
      now = DateTime.utc(2026, 11, 18, 9);
      server = FakeShareServer(clock: () => now);
      sharer = ReportSharer(server, clock: () => now);
      store = AppStore.memory();
    });

    test('uploads only ciphertext, and the link opens the report', () async {
      final link = await sharer.create(store, _pdf, ShareExpiry.week);
      final uploaded = server.boxes[link.id]!.box;
      expect(uploaded, isNot(_pdf));
      expect(utf8.decode(uploaded, allowMalformed: true), isNot(contains('%PDF')));
      expect(Uri.parse(link.url).fragment, hasLength(43));
      expect(await openLink(server, link.url), _pdf);
      expect(store.activeReportLinks(now).single.id, link.id);
    });

    test('links expire after the chosen time', () async {
      for (final e in ShareExpiry.values) {
        final link = await sharer.create(store, _pdf, e);
        expect(link.expiresAt, now.add(Duration(days: e.days)));
      }
      expect(ShareExpiry.fallback, ShareExpiry.week);

      final day = store.sharedReportLinks.firstWhere((l) => l.expiresAt == now.add(const Duration(days: 1)));
      now = now.add(const Duration(days: 1, minutes: 1));
      expect(store.activeReportLinks(now).map((l) => l.id), isNot(contains(day.id)));
      await expectLater(openLink(server, day.url), throwsA(isA<ShareApiException>().having((e) => e.status, 'status', 404)));
    });

    test('revoking deletes it on the server and forgets it here', () async {
      final link = await sharer.create(store, _pdf, ShareExpiry.month);
      await sharer.revoke(store, link);
      expect(server.revoked, [link.id]);
      expect(store.sharedReportLinks, isEmpty);
      await expectLater(openLink(server, link.url), throwsA(isA<ShareApiException>()));
    });

    test('an expired link is forgotten without calling the server', () async {
      final link = await sharer.create(store, _pdf, ShareExpiry.day);
      now = now.add(const Duration(days: 2));
      await sharer.revoke(store, link);
      expect(server.revoked, isEmpty);
      expect(store.sharedReportLinks, isEmpty);
    });

    test('saving prunes links that expired more than a day ago', () async {
      final old = await sharer.create(store, _pdf, ShareExpiry.day);
      now = now.add(const Duration(days: 3));
      await sharer.create(store, _pdf, ShareExpiry.week);
      expect(store.sharedReportLinks.map((l) => l.id), isNot(contains(old.id)));
      expect(store.sharedReportLinks, hasLength(1));
    });

    test('the saved list survives a JSON round trip', () async {
      final link = await sharer.create(store, _pdf, ShareExpiry.week);
      final restored = SharedReportLink.fromJson(jsonDecode(jsonEncode(link.toJson())))!;
      expect(restored.url, link.url);
      expect(restored.revokeToken, link.revokeToken);
      expect(restored.expiresAt, link.expiresAt);
      expect(SharedReportLink.fromJson({'id': 1}), isNull);
    });
  });

  group('HTTP client', () {
    final endpoint = Uri.parse('https://bloom.example.com/api/share');

    test('posts the box with the expiry and reads the reply', () async {
      late http.Request seen;
      final api = HttpReportShareApi(endpoint, client: MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({'id': 'A' * 22, 'revokeToken': 'B' * 43, 'expiresAt': '2026-11-25T09:00:00.000Z'}),
          201,
        );
      }));
      final box = Uint8List.fromList([1, 2, 3]);
      final created = await api.create(box, ShareExpiry.month);
      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'https://bloom.example.com/api/share?days=30');
      expect(seen.headers['Content-Type'], 'application/octet-stream');
      expect(seen.bodyBytes, box);
      expect(created.id, 'A' * 22);
      expect(created.expiresAt, DateTime.utc(2026, 11, 25, 9));
    });

    test('revokes with the token header and accepts 404', () async {
      final calls = <http.Request>[];
      final api = HttpReportShareApi(endpoint, client: MockClient((req) async {
        calls.add(req);
        return http.Response('', calls.length == 1 ? 204 : 404);
      }));
      await api.revoke('A' * 22, 'T' * 43);
      await api.revoke('A' * 22, 'T' * 43);
      expect(calls.first.method, 'DELETE');
      expect(calls.first.url.path, '/api/share/${'A' * 22}');
      expect(calls.first.headers['X-Bloom-Revoke-Token'], 'T' * 43);
    });

    test('shows the server\'s message on errors', () async {
      final api = HttpReportShareApi(endpoint, client: MockClient((_) async {
        return http.Response(jsonEncode({'error': {'code': 'rate_limited', 'message': 'Try again tomorrow.'}}), 429);
      }));
      await expectLater(
        api.create(Uint8List(4), ShareExpiry.week),
        throwsA(isA<ShareApiException>().having((e) => e.message, 'message', 'Try again tomorrow.')),
      );
    });

    test('a missing link is a 404', () async {
      final api = HttpReportShareApi(endpoint, client: MockClient((_) async => http.Response('', 404)));
      await expectLater(api.fetch('A' * 22), throwsA(isA<ShareApiException>().having((e) => e.status, 'status', 404)));
    });
  });

  group('screen', () {
    void phone(WidgetTester t) {
      t.view
        ..physicalSize = const Size(1170, 2532)
        ..devicePixelRatio = 3;
      addTearDown(t.view.reset);
    }

    Widget app(AppStore store, Widget child) => ChangeNotifierProvider.value(
          value: store,
          child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
        );

    Future<void> settle(WidgetTester t, bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump();
      }
      await t.pumpAndSettle();
    }

    testWidgets('without a share service there is no Share link button', (t) async {
      phone(t);
      await t.pumpWidget(app(AppStore.memory(), const DoctorReportScreen()));
      await t.pumpAndSettle();
      expect(find.text('Print or save PDF'), findsOneWidget);
      expect(find.text('Share link'), findsNothing);
    });

    testWidgets('creates a link, shows the warning and expiry, then turns it off', (t) async {
      phone(t);
      final store = AppStore.memory();
      final server = FakeShareServer();
      await t.pumpWidget(app(store, DoctorReportScreen(shareApi: server, buildPdf: (_) async => _pdf)));
      await t.pumpAndSettle();

      await t.tap(find.text('Share link'));
      await t.pumpAndSettle();
      expect(find.text('Anyone with the link can read it'), findsOneWidget);
      expect(find.textContaining('Anyone with the link can open and read this report'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);

      await t.tap(find.text('30 days'));
      await t.pump();
      await t.tap(find.text('Create link'));
      await settle(t, () => find.text('Your link is ready').evaluate().isNotEmpty);

      expect(find.text('Your link is ready'), findsOneWidget);
      final link = store.sharedReportLinks.single;
      expect(link.expiresAt.difference(link.createdAt).inMinutes, closeTo(30 * 24 * 60, 1));
      expect(find.text(link.url), findsOneWidget);
      expect(find.textContaining('It stops working on'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Share'), findsWidgets);
      expect(await t.runAsync(() => openLink(server, link.url)), _pdf);

      // Close the sheet. The report screen lists the link.
      Navigator.of(t.element(find.text('Your link is ready'))).pop();
      await t.pumpAndSettle();
      expect(find.text('Shared links'.toUpperCase()), findsOneWidget);
      expect(find.textContaining('Expires '), findsOneWidget);

      await t.ensureVisible(find.text('Turn off'));
      await t.tap(find.text('Turn off'));
      await t.pumpAndSettle();
      expect(find.text('Turn off this link?'), findsOneWidget);
      // The dialog's button is the last "Turn off" in the tree.
      await t.tap(find.text('Turn off').last);
      await settle(t, () => store.sharedReportLinks.isEmpty);

      expect(server.revoked, [link.id]);
      expect(store.sharedReportLinks, isEmpty);
      expect(find.textContaining('Expires '), findsNothing);
    });

    testWidgets('shows the server\'s error in the sheet', (t) async {
      phone(t);
      final store = AppStore.memory();
      final api = HttpReportShareApi(
        Uri.parse('https://bloom.example.com/api/share'),
        client: MockClient((_) async => http.Response(
              jsonEncode({'error': {'code': 'busy', 'message': 'Sharing is busy right now. Try again later.'}}),
              503,
            )),
      );
      await t.pumpWidget(app(store, DoctorReportScreen(shareApi: api, buildPdf: (_) async => _pdf)));
      await t.pumpAndSettle();
      await t.tap(find.text('Share link'));
      await t.pumpAndSettle();
      await t.tap(find.text('Create link'));
      await settle(t, () => find.textContaining('busy').evaluate().isNotEmpty);
      expect(find.text('Sharing is busy right now. Try again later.'), findsOneWidget);
      expect(store.sharedReportLinks, isEmpty);
    });
  });
}
