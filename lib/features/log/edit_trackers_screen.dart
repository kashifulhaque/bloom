/// Lets the user show, hide, and reorder the trackers in the log sheet.
library;

import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'tracker_style.dart';
import 'trackers.dart';

class EditTrackersScreen extends StatelessWidget {
  const EditTrackersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final profile = store.profile;
    final items = orderedTrackers(profile, includeHidden: true);
    final shownCount = items.where((t) => !profile.hiddenTrackers.contains(t.id)).length;
    final customized = profile.hiddenTrackers.isNotEmpty || profile.trackerOrder.isNotEmpty;

    return Scaffold(
      body: BloomPage(
        title: 'Edit categories',
        subtitle: 'Turn categories on or off, and drag the handle to change their order.',
        actions: [
          TextButton(
            onPressed: customized
                ? () => store.updateProfile((p) {
                      p.hiddenTrackers = [];
                      p.trackerOrder = [];
                    })
                : null,
            child: const Text('Reset'),
          ),
        ],
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: Space.xs, bottom: Space.md),
              child: Text(
                '$shownCount of ${items.length} shown'.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: BloomTokens.of(context).muted,
                      letterSpacing: 1,
                    ),
              ),
            ),
          ),
          SliverReorderableList(
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) {
              final ids = items.map((t) => t.id).toList();
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              store.updateProfile((p) => p.trackerOrder = ids);
            },
            proxyDecorator: (child, index, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Transform.scale(
                scale: lerpDouble(1, 1.03, Curves.easeOut.transform(animation.value))!,
                child: child,
              ),
              child: Material(type: MaterialType.transparency, child: child),
            ),
            itemBuilder: (context, i) {
              final t = items[i];
              return Padding(
                key: ValueKey(t.id),
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: _TrackerRow(
                  item: t,
                  index: i,
                  shown: !profile.hiddenTrackers.contains(t.id),
                  onChanged: (on) => store.updateProfile((p) {
                    final hidden = {...p.hiddenTrackers};
                    on ? hidden.remove(t.id) : hidden.add(t.id);
                    p.hiddenTrackers = hidden.toList();
                  }),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow({required this.item, required this.index, required this.shown, required this.onChanged});

  final TrackerItem item;
  final int index;
  final bool shown;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    return BloomCard(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.sm),
      onTap: () => onChanged(!shown),
      child: AnimatedOpacity(
        duration: Motion.medium,
        opacity: shown ? 1 : 0.55,
        child: Row(
          children: [
            IconBadge(emoji: item.emoji, color: trackerColor(item), size: 40),
            Gap.h12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    item.category != null
                        ? '${item.category!.options.length} options'
                        : 'Number tracker',
                    style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
            Switch(value: shown, onChanged: onChanged),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Icon(Icons.drag_indicator_rounded, color: tokens.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
