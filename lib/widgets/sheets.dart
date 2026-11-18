/// Bottom sheets: [showAppBottomSheet] and [AppBottomSheet].
library;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Shows a paper bottom sheet with a thin drag handle and a hairline top
/// edge, capped at 640 px wide on desktop, that grows with its content and
/// avoids the keyboard.
///
/// Wrap the content in [AppBottomSheet] for the standard title and padding:
///
/// ```dart
/// showAppBottomSheet(context, builder: (context) => AppBottomSheet(
///   title: 'Add a note',
///   child: TextField(...),
///   actions: [FilledButton(onPressed: ..., child: Text('Save'))],
/// ));
/// ```
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    useRootNavigator: useRootNavigator,
    showDragHandle: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 360),
      reverseDuration: Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    ),
  );
}

/// Standard bottom sheet content: an optional mono [eyebrow], a serif title
/// and muted subtitle, a scrollable body, and a row of actions pinned to the
/// bottom.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.actions = const [],
    this.padding = Insets.sheet,
    this.eyebrow,
  });

  /// Small mono label above the title. Uppercased.
  final String? eyebrow;

  final String? title;
  final String? subtitle;
  final Widget child;

  /// Buttons at the bottom. A single action stretches to full width.
  final List<Widget> actions;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: Motion.fast,
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (eyebrow != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Text(eyebrow!.toUpperCase(), style: Almanac.label(context), semanticsLabel: eyebrow),
                ),
              if (title != null) Text(title!, style: theme.textTheme.headlineSmall),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(subtitle!, style: theme.textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2)),
                ),
              if (title != null || subtitle != null) Gap.v20,
              Flexible(child: SingleChildScrollView(child: child)),
              if (actions.isNotEmpty) ...[
                Gap.v20,
                if (actions.length == 1)
                  actions.single
                else
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) Gap.h12,
                        Expanded(child: actions[i]),
                      ],
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
