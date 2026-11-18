/// Lets the user show, hide, and reorder the trackers in the log sheet.
library;

import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'almanac_rows.dart';
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
        eyebrow: 'Log sheet',
        title: 'Edit categories',
        subtitle: 'Turn categories on or off, and drag the handle to change their order.',
        actions: [
          AnimatedOpacity(
            duration: Motion.fast,
            opacity: customized ? 1 : 0.4,
            child: InkLink(
              'Reset',
              size: 13.5,
              onTap: customized
                  ? () => store.updateProfile((p) {
                        p.hiddenTrackers = [];
                        p.trackerOrder = [];
                      })
                  : null,
            ),
          ),
        ],
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: MonoLabel('$shownCount of ${items.length} shown'),
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
              child: ColoredBox(color: BloomColors.of(context).raised, child: child),
            ),
            itemBuilder: (context, i) {
              final t = items[i];
              return KeyedSubtree(
                key: ValueKey(t.id),
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
    final p = BloomColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
      child: Pressable(
        onTap: () => onChanged(!shown),
        semanticLabel: item.title,
        selected: shown,
        child: AnimatedOpacity(
          duration: Motion.medium,
          opacity: shown ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                ToneDot(trackerColor(item), size: 7),
                Gap.h12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: Almanac.serif(size: 18, weight: 370, color: p.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        item.category != null ? '${item.category!.options.length} options' : 'Number tracker',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                InkSwitch(value: shown, onChanged: onChanged, semanticLabel: 'Show ${item.title}'),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, 0, Space.md),
                    child: Icon(Icons.drag_handle, size: 20, color: p.ink2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
