/// Partner sharing: create a read-only snapshot code with a QR code, or
/// open a code someone shared with you.
library;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/dates.dart';
import '../../core/engine.dart';
import '../../core/store.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart';
import 'partner_snapshot.dart';
import 'partner_tips.dart';

class PartnerScreen extends StatefulWidget {
  const PartnerScreen({super.key});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BloomPage(
        title: 'Partner sharing',
        heroColor: BloomColors.brand,
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Share'), icon: Icon(Icons.ios_share_rounded)),
              ButtonSegment(value: 1, label: Text('I\'m a partner'), icon: Icon(Icons.favorite_rounded)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          AnimatedSwitcher(
            duration: Motion.medium,
            switchInCurve: Motion.curve,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: _tab == 0 ? const _ShareTab(key: ValueKey(0)) : const _PartnerTab(key: ValueKey(1)),
          ),
        ],
      ),
    );
  }
}

/// Stacks [children] 16 px apart, like [BloomPage] does.
class _Stack extends StatelessWidget {
  const _Stack(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.v16, children[i]],
    ],
  );
}

class _ShareTab extends StatelessWidget {
  const _ShareTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final state = PartnerState.of(store);
    final o = state.options;
    final theme = Theme.of(context);

    void setOption(void Function(ShareOptions o) change) {
      change(o);
      // Regenerate so the code always matches the current choices.
      if (state.code != null) {
        final id = PartnerSnapshot.decode(state.code!).id;
        state.code = buildSnapshot(store, o, id: id).encode();
      }
      state.save(store);
    }

    void generate() {
      state.code = buildSnapshot(store, o, id: newSnapshotId()).encode();
      state.save(store);
    }

    Future<void> stop() async {
      final ok = await confirmDialog(
        context,
        title: 'Stop sharing?',
        message:
            'Bloom will stop showing this code. Because sharing works offline, anyone who already has the '
            'code keeps that snapshot, but they won\'t get updates.',
        confirm: 'Stop sharing',
      );
      if (!ok) return;
      state.code = null;
      state.save(store);
    }

    return _Stack([
      AnimatedSwitcher(
        duration: Motion.medium,
        child: state.code == null
            ? BloomCard.gradient(
                key: const ValueKey('intro'),
                gradient: BloomGradients.dusk,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: Radii.mdAll),
                      child: const Icon(Icons.qr_code_2_rounded, size: 30),
                    ),
                    Gap.v16,
                    Text('Share your cycle', style: theme.textTheme.headlineSmall!.copyWith(color: Colors.white)),
                    Gap.v8,
                    Text(
                      'Give a partner a read-only snapshot. Nothing is uploaded: the code itself holds the data, '
                      'so share a new one each cycle.',
                      style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                    ),
                    Gap.v20,
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: BloomColors.brandDeep,
                        ),
                        onPressed: generate,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Create a partner code'),
                      ),
                    ),
                  ],
                ),
              )
            : _CodeCard(key: const ValueKey('code'), code: state.code!, onRegenerate: generate, onStop: stop),
      ),
      MenuSection(
        title: 'What to share',
        footer: state.code == null
            ? null
            : 'Changes update your code right away. Share it again so your partner sees them.',
        children: [
          MenuTile.toggle(
            icon: Icons.badge_rounded,
            color: BloomColors.info,
            title: 'My name',
            value: o.name,
            onChanged: (v) => setOption((o) => o.name = v),
          ),
          MenuTile.toggle(
            icon: Icons.water_drop_rounded,
            color: BloomColors.period,
            title: 'Period predictions',
            subtitle: 'Current cycle start and the next 3 predicted periods',
            value: o.predictions,
            onChanged: (v) => setOption((o) => o.predictions = v),
          ),
          MenuTile.toggle(
            icon: Icons.spa_rounded,
            color: BloomColors.fertile,
            title: 'Fertile window and ovulation',
            value: o.fertility,
            onChanged: (v) => setOption((o) => o.fertility = v),
          ),
          MenuTile.toggle(
            icon: Icons.lightbulb_rounded,
            color: BloomColors.luteal,
            title: 'Current phase and tips',
            value: o.phase,
            onChanged: (v) => setOption((o) => o.phase = v),
          ),
          MenuTile.toggle(
            icon: Icons.child_friendly_rounded,
            color: BloomColors.pregnancy,
            title: 'Pregnancy progress',
            subtitle: 'Week and due date, in pregnancy mode',
            value: o.pregnancy,
            onChanged: (v) => setOption((o) => o.pregnancy = v),
          ),
          MenuTile.toggle(
            icon: Icons.mood_rounded,
            color: BloomColors.coral,
            title: 'Recent moods',
            subtitle: 'From the last 3 days. Never shared in pregnancy mode.',
            value: o.moods,
            onChanged: (v) => setOption((o) => o.moods = v),
          ),
          MenuTile.toggle(
            icon: Icons.healing_rounded,
            color: BloomColors.follicular,
            title: 'Recent symptoms',
            subtitle: 'From the last 3 days. Never shared in pregnancy mode.',
            value: o.symptoms,
            onChanged: (v) => setOption((o) => o.symptoms = v),
          ),
        ],
      ),
    ]);
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({super.key, required this.code, required this.onRegenerate, required this.onStop});
  final String code;
  final VoidCallback onRegenerate;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final snap = PartnerSnapshot.decode(code);
    final theme = Theme.of(context);
    final tokens = BloomTokens.of(context);
    final age = daysBetween(snap.generated, today());
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.qr_code_2_rounded, color: BloomColors.brand),
              Gap.h12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your partner code',
                      style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      age <= 0 ? 'Snapshot from today' : 'Snapshot from ${fmtFull(snap.generated)}',
                      style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ),
              const PillChip('Sharing', dense: true, icon: Icons.check_circle_rounded, color: BloomColors.success),
            ],
          ),
          Gap.v20,
          Center(
            child: Container(
              padding: Insets.all16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: Radii.lgAll,
                border: Border.all(color: tokens.border),
                boxShadow: tokens.cardShadow,
              ),
              child: QrImageView(
                data: code,
                size: 200,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: BloomColors.brandDeep),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: BloomColors.onColor(Colors.white),
                ),
                semanticsLabel: 'QR code for your partner snapshot',
              ),
            ),
          ),
          Gap.v16,
          Text(
            'Your partner opens Bloom, goes to Me, Partner sharing, I\'m a partner, and scans or pastes this code.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted),
          ),
          Gap.v12,
          Material(
            color: tokens.subtle,
            borderRadius: Radii.mdAll,
            child: InkWell(
              borderRadius: Radii.mdAll,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) showSnack(context, 'Code copied');
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall!.copyWith(color: tokens.muted, letterSpacing: 0.5),
                      ),
                    ),
                    Gap.h8,
                    Icon(Icons.copy_rounded, size: 18, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
          Gap.v16,
          FilledButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text:
                    'Here\'s my Bloom partner code. Open Bloom, go to Me > Partner sharing > I\'m a partner, '
                    'and paste it:\n\n$code',
                subject: 'Bloom partner code',
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share code'),
          ),
          Gap.v8,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Update'),
                ),
              ),
              Gap.h8,
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: readableTint(theme.colorScheme.error, theme.brightness)),
                  onPressed: onStop,
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Stop sharing'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerTab extends StatefulWidget {
  const _PartnerTab({super.key});

  @override
  State<_PartnerTab> createState() => _PartnerTabState();
}

class _PartnerTabState extends State<_PartnerTab> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(AppStore store) {
    try {
      PartnerSnapshot.decode(_controller.text);
      final s = PartnerState.of(store)..viewed = _controller.text.trim();
      s.save(store);
      setState(() => _error = null);
      _controller.clear();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final state = PartnerState.of(store);
    final theme = Theme.of(context);
    PartnerSnapshot? snap;
    if (state.viewed != null) {
      try {
        snap = PartnerSnapshot.decode(state.viewed!);
      } on FormatException {
        snap = null;
      }
    }

    final input = BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (snap == null) ...[
            const EmptyState(
              compact: true,
              icon: Icons.favorite_rounded,
              color: BloomColors.brand,
              title: 'See your partner\'s cycle',
              body:
                  'Paste the code your partner shared from their Bloom app to see their cycle summary and tips on '
                  'how to support them.',
            ),
            Gap.v20,
          ] else ...[
            Text('Open a newer code', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
            Gap.v12,
          ],
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Partner code',
              hintText: 'BLOOM1....',
              errorText: _error,
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          Gap.v12,
          FilledButton.icon(
            onPressed: () => _open(store),
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('View snapshot'),
          ),
        ],
      ),
    );

    return _Stack([
      if (snap != null) ...[
        PartnerView(snapshot: snap),
        OutlinedButton.icon(
          onPressed: () {
            state.viewed = null;
            state.save(store);
          },
          icon: const Icon(Icons.close_rounded),
          label: const Text('Remove this snapshot'),
        ),
      ],
      input,
    ]);
  }
}

/// Read-only partner view of a snapshot.
class PartnerView extends StatelessWidget {
  const PartnerView({super.key, required this.snapshot});
  final PartnerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final now = today();
    final theme = Theme.of(context);
    final who = s.name ?? 'Your partner';
    final age = daysBetween(s.generated, now);
    final phase = s.phaseOn(now);
    final next = s.nextPeriodAfter(now);
    final nextOv = s.ovulations.where((o) => !o.isBefore(addDays(now, -1))).firstOrNull;
    final shared = age <= 0 ? 'Shared today' : 'Shared ${fmtShort(s.generated)} · $age day${age == 1 ? '' : 's'} ago';
    final white = Colors.white.withValues(alpha: 0.88);
    final pregnant = s.pregnant && s.dueDate != null;

    Widget hero;
    List<String> tips;
    if (pregnant) {
      final lmp = addDays(s.dueDate!, -280);
      final d = daysBetween(lmp, now).clamp(0, 300);
      final weeks = d ~/ 7;
      tips = partnerPregnancyTips(weeks);
      hero = BloomCard.gradient(
        gradient: BloomGradients.pregnancy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PillChip(shared, solid: true, dense: true, color: Colors.white),
            Gap.v12,
            Text('$who\'s pregnancy', style: theme.textTheme.titleMedium!.copyWith(color: white)),
            Gap.v4,
            Text('Week $weeks, day ${d % 7}', style: theme.textTheme.headlineMedium!.copyWith(color: Colors.white)),
            Gap.v4,
            Text(
              'Due around ${fmtFull(s.dueDate!)} · ${daysBetween(now, s.dueDate!)} days to go',
              style: theme.textTheme.bodyMedium!.copyWith(color: white),
            ),
          ],
        ),
      );
    } else {
      tips = phase == null ? const [] : partnerPhaseTips(phase);
      hero = BloomCard.gradient(
        gradient: phase == null ? BloomGradients.dusk : phaseGradient(phase),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PillChip(shared, solid: true, dense: true, color: Colors.white),
            Gap.v12,
            Text('$who\'s cycle', style: theme.textTheme.titleMedium!.copyWith(color: white)),
            Gap.v4,
            Text(
              phase == null ? 'No phase shared' : phase.label,
              style: theme.textTheme.headlineMedium!.copyWith(color: Colors.white),
            ),
            if (phase != null) ...[
              Gap.v8,
              Text(partnerPhaseSummary(phase), style: theme.textTheme.bodyMedium!.copyWith(color: white)),
            ],
          ],
        ),
      );
    }

    return _Stack([
      hero,
      if (age > 35)
        const InfoBanner(
          tone: BannerTone.warning,
          message: 'This snapshot is over a month old. Ask for a new code for current predictions.',
        ),
      if (!pregnant && (next != null || nextOv != null))
        Row(
          children: [
            if (next != null)
              Expanded(
                child: StatTile(
                  icon: Icons.water_drop_rounded,
                  color: BloomColors.period,
                  value: '${daysBetween(now, next)}',
                  unit: daysBetween(now, next) == 1 ? 'day' : 'days',
                  label: 'Until next period',
                  caption: fmtShort(next),
                ),
              ),
            if (next != null && nextOv != null) Gap.h12,
            if (nextOv != null)
              Expanded(
                child: StatTile(
                  icon: Icons.spa_rounded,
                  color: BloomColors.fertile,
                  value: fmtShort(addDays(nextOv, -5)),
                  label: 'Fertile window',
                  caption: 'to ${fmtShort(addDays(nextOv, 1))}',
                ),
              ),
          ],
        ),
      if (tips.isNotEmpty)
        BloomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(icon: Icons.volunteer_activism_rounded, color: BloomColors.brand),
                  Gap.h12,
                  Text('How to support', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              Gap.v12,
              for (final tip in tips)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.favorite_rounded, size: 14, color: theme.colorScheme.primary),
                      ),
                      Gap.h12,
                      Expanded(child: Text(tip, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (s.moods.isNotEmpty || s.symptoms.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Recently logged'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in s.moods) PillChip(m, icon: Icons.mood_rounded, color: BloomColors.coral),
                for (final m in s.symptoms) PillChip(m, icon: Icons.healing_rounded, color: BloomColors.luteal),
              ],
            ),
          ],
        ),
      if (s.periodStarts.isNotEmpty || s.ovulations.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Next 5 weeks'),
            _MiniCalendar(snapshot: s, from: now),
          ],
        ),
      const Disclaimer(text: 'Predictions are estimates and aren\'t birth control.'),
    ]);
  }
}

class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({required this.snapshot, required this.from});
  final PartnerSnapshot snapshot;
  final DateTime from;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstDow = context.read<AppStore>().profile.firstDayOfWeek;
    final start = addDays(from, -((from.weekday - firstDow + 7) % 7));
    return BloomCard(
      padding: Insets.cardCompact,
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('E').format(addDays(start, i)).substring(0, 1),
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(color: BloomTokens.of(context).muted),
                    ),
                  ),
                ),
            ],
          ),
          Gap.v4,
          for (var w = 0; w < 5; w++)
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final d = addDays(start, w * 7 + i);
                        final period = snapshot.isPeriodDay(d);
                        final ov = snapshot.isOvulation(d);
                        final fertile = snapshot.isFertile(d);
                        final bg = period
                            ? BloomColors.period
                            : ov
                            ? BloomColors.ovulation
                            : fertile
                            ? BloomColors.fertile.withValues(alpha: 0.35)
                            : Colors.transparent;
                        return Container(
                          margin: const EdgeInsets.all(2),
                          height: 34,
                          decoration: BoxDecoration(
                            color: bg,
                            shape: BoxShape.circle,
                            border: sameDay(d, from) ? Border.all(color: scheme.primary, width: 2) : null,
                          ),
                          child: Center(
                            child: Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 12,
                                color: period || ov
                                    ? Colors.white
                                    : (d.isBefore(from) ? BloomTokens.of(context).muted.withValues(alpha: 0.6) : null),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          Gap.v8,
          Wrap(
            spacing: Space.md,
            children: [
              _dot(context, BloomColors.period, 'Period'),
              _dot(context, BloomColors.fertile.withValues(alpha: 0.5), 'Fertile'),
              _dot(context, BloomColors.ovulation, 'Ovulation'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(BuildContext context, Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      Gap.h4,
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
