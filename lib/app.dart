/// App root: theme, onboarding/lock gates, and the tab shell.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/store.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/lock_screen.dart';
import 'features/today/today_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/buttons.dart' show BloomLogo;

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
      home: AnimatedSwitcher(
        duration: Motion.medium,
        child: !store.profile.onboarded
            ? const OnboardingScreen()
            : store.locked
                ? const LockScreen()
                : const HomeShell(),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The main shell holding the five tabs.
///
/// Phones and tablets get a bottom [NavigationBar]. At 900 px and wider, the
/// shell switches to a [NavigationRail] with the Bloom logo so the desktop web
/// layout looks intentional. Tabs keep their state and cross-fade on switch.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Width at which the shell switches from a bottom bar to a side rail.
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
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  static const _pages = [TodayScreen(), CalendarScreen(), InsightsScreen(), AssistantScreen(), ProfileScreen()];

  static const _destinations = [
    _Destination('Today', Icons.wb_twilight_rounded, Icons.wb_twilight_rounded),
    _Destination('Calendar', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
    _Destination('Insights', Icons.auto_stories_outlined, Icons.auto_stories_rounded),
    _Destination('Assistant', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    _Destination('Me', Icons.person_outline_rounded, Icons.person_rounded),
  ];

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
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= HomeShell.railBreakpoint;
    final tokens = BloomTokens.of(context);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.surfaceContainerLow,
                border: Border(right: BorderSide(color: tokens.border)),
              ),
              child: SafeArea(
                right: false,
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: Space.xl, bottom: Space.xxxl),
                    child: BloomLogo(size: 44),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      );
    }

    return Scaffold(
      body: _body(),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tokens.border)),
          boxShadow: theme.brightness == Brightness.light
              ? const [BoxShadow(color: Color(0x0D7A2E4A), blurRadius: 16, offset: Offset(0, -4))]
              : null,
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          animationDuration: Motion.slow,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      ),
    );
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
            child: AnimatedSlide(
              offset: active ? Offset.zero : const Offset(0, 0.012),
              duration: Motion.medium,
              curve: Motion.curve,
              child: TickerMode(enabled: active, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
