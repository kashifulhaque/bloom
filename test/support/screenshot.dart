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

  await family('Outfit', ['assets/fonts/Outfit-Medium.ttf', 'assets/fonts/Outfit-SemiBold.ttf', 'assets/fonts/Outfit-Bold.ttf']);
  await family('Nunito', [
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-SemiBold.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-ExtraBold.ttf',
  ]);
  await family('BloomEmoji', ['assets/fonts/BloomEmoji.ttf']);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }
}

/// Pumps [child] inside the app theme at phone size and saves a PNG named
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
      home: RepaintBoundary(key: const ValueKey('shot'), child: child),
    ),
  ));
  await tester.pump(const Duration(seconds: 2));
  if (interact != null) {
    await interact(tester);
    await tester.pump(const Duration(seconds: 2));
  }
  await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('goldens/$name.png'));
}
