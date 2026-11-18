import 'dart:convert';

import 'package:bloom/core/store.dart';
import 'package:bloom/features/downloads/download_manifest.dart';
import 'package:bloom/features/downloads/get_app_screen.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

final _apkHash = 'a' * 64;
final _ipaHash = 'B' * 64;
final _cert = List.filled(32, '8F').join(':');

Map<String, dynamic> _valid() => {
      'version': '1.0.0+42',
      'builtAt': '2026-11-18T10:00:00Z',
      'apk': {'file': 'bloom.apk', 'bytes': 21456789, 'sha256': _apkHash},
      'ipa': {'file': 'bloom-unsigned.ipa', 'bytes': 19876543, 'sha256': _ipaHash},
      'signingCertSha256': _cert,
    };

void main() {
  group('manifest parsing', () {
    test('valid', () {
      final m = DownloadManifest.tryParse(_valid())!;
      expect(m.version, '1.0.0+42');
      expect(m.builtAt, DateTime.utc(2026, 11, 18, 10));
      expect(m.apk!.path, '/downloads/bloom.apk');
      expect(m.apk!.bytes, 21456789);
      expect(m.ipa!.file, 'bloom-unsigned.ipa');
      expect(m.ipa!.sha256, 'b' * 64);
      expect(m.signingCertSha256, _cert);
      expect(formatBytes(21456789), '21.5 MB');
    });

    test('malformed', () {
      expect(DownloadManifest.tryParseBody('<!doctype html><html></html>'), isNull);
      expect(DownloadManifest.tryParseBody('[]'), isNull);
      expect(DownloadManifest.tryParse(_valid()..remove('version')), isNull);
      expect(DownloadManifest.tryParse(_valid()..remove('apk')..remove('ipa')), isNull);
      // A bad entry is dropped; the other stays.
      final badApk = _valid()..['apk'] = {'file': '../etc/passwd', 'bytes': 1, 'sha256': _apkHash};
      expect(DownloadManifest.tryParse(badApk)!.apk, isNull);
      final badHash = _valid()..['ipa'] = {'file': 'x.ipa', 'bytes': 1, 'sha256': 'nothex'};
      expect(DownloadManifest.tryParse(badHash)!.ipa, isNull);
      final badSize = _valid()..['apk'] = {'file': 'bloom.apk', 'bytes': '12', 'sha256': _apkHash};
      expect(DownloadManifest.tryParse(badSize)!.apk, isNull);
      final badCert = _valid()..['signingCertSha256'] = 'nope';
      expect(DownloadManifest.tryParse(badCert)!.signingCertSha256, isNull);
    });

    test('fetch: same origin, missing, malformed, offline', () async {
      final base = Uri.parse('https://bloom.ifkash.dev/today');
      final urls = <Uri>[];
      Future<DownloadManifest?> fetch(http.Response Function() respond) => fetchDownloadManifest(
            base: base,
            client: MockClient((r) async {
              urls.add(r.url);
              return respond();
            }),
          );
      expect((await fetch(() => http.Response(jsonEncode(_valid()), 200)))?.version, '1.0.0+42');
      expect(urls.single.toString(), 'https://bloom.ifkash.dev/downloads/manifest.json');
      expect(await fetch(() => http.Response('Not found', 404)), isNull);
      expect(await fetch(() => http.Response('<html>app shell</html>', 200)), isNull);
      expect(
        await fetchDownloadManifest(base: base, client: MockClient((_) async => throw http.ClientException('offline'))),
        isNull,
      );
    });
  });

  group('Get the app', () {
    Widget wrap(Widget child) => ChangeNotifierProvider.value(
          value: AppStore.memory(),
          child: MaterialApp(theme: buildTheme(Brightness.light), home: child),
        );

    testWidgets('shows the facts and downloads the APK', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saved = <(Uri, String)>[];
      await tester.pumpWidget(wrap(GetAppScreen(
        loadManifest: () async => DownloadManifest.tryParse(_valid()),
        saveFile: (u, n) => saved.add((u, n)),
        base: Uri.parse('https://bloom.ifkash.dev/'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('1.0.0+42'), findsOneWidget);
      expect(find.text('${'a' * 32}\n${'a' * 32}'), findsOneWidget);
      expect(find.textContaining('8F:8F:8F:8F:8F:8F:8F:8F:\n'), findsOneWidget);
      expect(find.text('21.5 MB'), findsOneWidget);
      expect(find.textContaining('turn on Install unknown apps'), findsOneWidget);
      expect(find.textContaining("can't install it directly"), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('download-apk')));
      await tester.tap(find.byKey(const ValueKey('download-ipa')));
      expect(saved, [
        (Uri.parse('https://bloom.ifkash.dev/downloads/bloom.apk'), 'bloom.apk'),
        (Uri.parse('https://bloom.ifkash.dev/downloads/bloom-unsigned.ipa'), 'bloom-unsigned.ipa'),
      ]);
    });

    testWidgets('missing manifest says not available yet', (tester) async {
      await tester.pumpWidget(wrap(GetAppScreen(loadManifest: () async => null)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('downloads-missing')), findsOneWidget);
      expect(find.byKey(const ValueKey('download-apk')), findsNothing);
    });
  });
}
