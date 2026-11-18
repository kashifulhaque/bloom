/// Renders a screen to a PNG so agents can look at it without a browser.
///
/// Usage, in a test file under `test/shots/`:
///
/// ```dart
/// testWidgets('today', (t) async {
///   final store = AppStore.memory();
///   loadDemoData(store, seed: 1);
///   await shoot(t, 'today_light', store: store, child: const TodayScreen());
///   await shoot(t, 'today_dark', store: store, child: const TodayScreen(), dark: true);
/// });
/// ```
///
/// Run `flutter test test/shots/<file> --update-goldens`, then open
/// `test/shots/goldens/<name>.png`. Screenshot files are scratch output; don't
/// keep them in the repository.
library;

import 'dart:io';

import 'package:bloom/core/store.dart';
import 'package:bloom/theme/app_theme.dart';
import 'package:bloom/widgets/paper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

bool _fontsLoaded = false;

/// Loads the bundled fonts (and Material icons) so text renders for real.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  await family('Fraunces', ['assets/fonts/Fraunces-VF.ttf', 'assets/fonts/Fraunces-Italic-VF.ttf']);
  await family('Hanken Grotesk', [
    'assets/fonts/HankenGrotesk-400.ttf',
    'assets/fonts/HankenGrotesk-500.ttf',
    'assets/fonts/HankenGrotesk-600.ttf',
    'assets/fonts/HankenGrotesk-700.ttf',
  ]);
  await family('IBM Plex Mono', ['assets/fonts/IBMPlexMono-Regular.ttf', 'assets/fonts/IBMPlexMono-Medium.ttf']);
  await family('BloomEmoji', ['assets/fonts/BloomEmoji.ttf']);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }
  // CupertinoIcons, for screens that use the thinner icon set.
  final pubCache = Platform.environment['PUB_CACHE'];
  if (pubCache != null) {
    final dir = Directory('$pubCache/hosted/pub.dev');
    if (dir.existsSync()) {
      final pkgs = dir.listSync().whereType<Directory>().where((d) => d.path.contains('cupertino_icons-')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (pkgs.isNotEmpty) {
        final f = File('${pkgs.last.path}/assets/CupertinoIcons.ttf');
        if (f.existsSync()) await family('packages/cupertino_icons/CupertinoIcons', [f.path]);
      }
    }
  }
}

/// Pumps [child] inside the app theme (with the app's paper background,
/// grain, and scroll behavior) at phone size and saves a PNG named
/// `test/shots/goldens/<name>.png`. Set [size] for desktop shots.
Future<void> shoot(
  WidgetTester tester,
  String name, {
  required AppStore store,
  required Widget child,
  bool dark = false,
  Size size = const Size(390, 844),
  Future<void> Function(WidgetTester t)? interact,
}) async {
  await tester.runAsync(loadAppFonts);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      scrollBehavior: const AlmanacScrollBehavior(),
      builder: (context, child) => RepaintBoundary(key: const ValueKey('shot'), child: PaperBackground(child: child!)),
      home: child,
    ),
  ));
  // Decode the grain texture for real so it shows in the PNG.
  await tester.runAsync(() => precacheImage(const AssetImage(PaperBackground.grainAsset), tester.element(find.byKey(const ValueKey('shot')))));
  // Two long frames: the first finishes the theme cross-fade, the second
  // finishes the text-style animations it starts (matters for dark shots).
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(seconds: 2));
  if (interact != null) {
    await interact(tester);
    await tester.pump(const Duration(seconds: 2));
  }
  await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('goldens/$name.png'));
}
