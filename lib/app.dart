/// App root: theme, onboarding/lock gates, and the tab shell.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/store.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/downloads/get_app_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/lock_screen.dart';
import 'features/today/today_screen.dart';
import 'widgets/widgets.dart';

class BloomApp extends StatelessWidget {
  const BloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final mode = switch (store.profile.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      // On the web this is the browser tab title.
      title: kIsWeb ? 'Bloom — period & cycle tracker' : 'Bloom',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      themeAnimationDuration: Motion.medium,
      scrollBehavior: const AlmanacScrollBehavior(),
      // Paper and grain under (and over) every route, sheet, and dialog.
      builder: (context, child) => PaperBackground(child: child ?? const SizedBox.shrink()),
      home: AnimatedSwitcher(
        duration: Motion.medium,
        child: !store.profile.onboarded
            ? const OnboardingScreen()
            : store.locked
                ? const LockScreen()
                : const HomeShell(),
      ),
      // On the web, /#/get-app opens "Get the app" over the home screen. It
      // shows no personal data, so it doesn't wait for onboarding or the lock.
      onGenerateRoute: (settings) => kIsWeb && settings.name == GetAppScreen.routeName
          ? MaterialPageRoute<void>(settings: settings, builder: (_) => const GetAppScreen())
          : null,
    );
  }
}

/// The main shell holding the five tabs.
///
/// Phones and tablets get a paper bar at the bottom: a top hairline and a
/// row of text labels with an underline under the active one. At 900 px and
/// wider, the shell switches to a left editorial column with the logo, the
/// app name in Fraunces, and vertical text links. Tabs keep their state and
/// cross-fade on switch.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Width at which the shell switches from the bottom bar to the side column.
  static const railBreakpoint = 900.0;

  /// Switches tabs from anywhere below the shell, e.g. `HomeShell.goTo(context, 1)`.
  static void goTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_HomeShellState>()?._select(index);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Tabs that have been opened at least once. Others aren't built yet.
  final Set<int> _visited = {0};

  void _select(int i) {
    if (i == _index) return;
    Almanac.tick();
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  static const _pages = [TodayScreen(), CalendarScreen(), InsightsScreen(), AssistantScreen(), ProfileScreen()];

  /// Tab labels, in the same order as [_pages] and [HomeShell.goTo] indices.
  static const _labels = ['Today', 'Calendar', 'Library', 'Ask', 'You'];

  /// Longer names for screen readers and the desktop column.
  static const _longLabels = ['Today', 'Calendar', 'Library', 'Ask Bloom', 'You'];

  Widget _body() {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < _pages.length; i++)
          if (_visited.contains(i)) _FadeTab(active: i == _index, child: _pages[i]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= HomeShell.railBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _SideColumn(index: _index, labels: _longLabels, onSelect: _select),
            const Hairline(vertical: true),
            Expanded(child: _body()),
          ],
        ),
      );
    }
    return Scaffold(
      body: _body(),
      bottomNavigationBar: _PaperTabBar(index: _index, labels: _labels, semanticLabels: _longLabels, onSelect: _select),
    );
  }
}

/// The phone navigation: a paper strip with a top hairline and five text
/// labels; the active one is ink with an underline.
class _PaperTabBar extends StatelessWidget {
  const _PaperTabBar({required this.index, required this.labels, required this.semanticLabels, required this.onSelect});

  final int index;
  final List<String> labels;
  final List<String> semanticLabels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: p.paper, border: Border(top: BorderSide(color: p.hairline))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.sm),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: _NavLabel(
                    label: labels[i],
                    semanticLabel: semanticLabels[i],
                    active: i == index,
                    onTap: () => onSelect(i),
                    align: Alignment.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The desktop navigation: an editorial column with the mark, the name in
/// Fraunces, vertical text links, and an ex libris note at the foot.
class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.index, required this.labels, required this.onSelect});

  final int index;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return SizedBox(
      width: 232,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.xxxl, Space.xxxl, Space.xxl, Space.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BloomLogo(size: 40),
              Gap.v12,
              Text('Bloom', style: Almanac.serif(size: 30, weight: 340, color: p.ink, height: 1)),
              Gap.v4,
              Text('a private almanac', style: Almanac.italic(context, size: 15, color: p.ink2)),
              Gap.v32,
              const Hairline(),
              Gap.v16,
              for (var i = 0; i < labels.length; i++)
                _NavLabel(
                  label: labels[i],
                  semanticLabel: labels[i],
                  active: i == index,
                  onTap: () => onSelect(i),
                  align: Alignment.centerLeft,
                  size: 16,
                  numeral: i + 1,
                ),
              const Spacer(),
              const MonoLabel('Your data stays\non this device', size: 9.5),
            ],
          ),
        ),
      ),
    );
  }
}

/// One navigation label with an animated underline indicator.
class _NavLabel extends StatelessWidget {
  const _NavLabel({
    required this.label,
    required this.semanticLabel,
    required this.active,
    required this.onTap,
    required this.align,
    this.size = 13.5,
    this.numeral,
  });

  final String label;
  final String semanticLabel;
  final bool active;
  final VoidCallback onTap;
  final Alignment align;
  final double size;

  /// A small mono index before the label (desktop column).
  final int? numeral;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final style = Almanac.sans(size: size, weight: FontWeight.w500, color: active ? p.ink : p.ink2, height: 1.2);
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align == Alignment.centerLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        AnimatedDefaultTextStyle(duration: Motion.medium, style: style, child: Text(label, maxLines: 1)),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          height: 1.5,
          width: active ? _textWidth(label, style) : 0,
          color: p.ink,
        ),
      ],
    );
    return Semantics(
      label: semanticLabel,
      selected: active,
      button: true,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        borderRadius: Radii.smAll,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: numeral == null ? 48 : 44),
          child: Align(
            alignment: align,
            widthFactor: align == Alignment.centerLeft ? null : 1,
            heightFactor: 1,
            child: numeral == null
                ? text
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(numeral!.toString().padLeft(2, '0'), style: Almanac.label(context, size: 10)),
                        ),
                      ),
                      text,
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  static double _textWidth(String s, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
    return tp.width;
  }
}

/// Keeps a tab alive and cross-fades it in and out. Inactive tabs don't take
/// input, focus, or semantics, and their animations pause.
class _FadeTab extends StatelessWidget {
  const _FadeTab({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeFocus(
        excluding: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: active ? Motion.medium : Motion.fast,
            curve: Motion.curve,
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}
