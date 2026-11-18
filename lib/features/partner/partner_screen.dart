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
        eyebrow: 'You · Partner sharing',
        title: 'Partner sharing',
        spacing: Space.xxl,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextChoices<int>(
                serif: true,
                spacing: Space.xl,
                options: const [
                  TextChoice(0, 'Share'),
                  TextChoice(1, 'I\'m a partner'),
                ],
                selected: _tab,
                onChanged: (v) => setState(() => _tab = v),
              ),
              const Hairline(),
            ],
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

/// Stacks [children] with section spacing, like [BloomPage] does.
class _Stack extends StatelessWidget {
  const _Stack(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.v24, children[i]],
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
    final p = BloomColors.of(context);
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
            ? Column(
                key: const ValueKey('intro'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MonoLabel('A letter'),
                  Gap.v12,
                  Text('Dear partner,', style: Almanac.italic(context, size: 26)),
                  Gap.v12,
                  Text(
                    'Give someone close a read-only snapshot of your cycle. Nothing is uploaded: the code itself '
                    'holds the data, so share a new one each cycle.',
                    style: theme.textTheme.bodyLarge!.copyWith(color: p.ink2),
                  ),
                  Gap.v20,
                  InkButton(label: 'Create a partner code', icon: Icons.qr_code_2, onPressed: generate),
                ],
              )
            : _CodeCard(key: const ValueKey('code'), code: state.code!, onRegenerate: generate, onStop: stop),
      ),
      MenuSection(
        title: 'What to share',
        footer: state.code == null
            ? null
            : 'Changes update your code right away. Share it again so your partner sees them.',
        children: [
          MenuTile.toggle(title: 'My name', value: o.name, onChanged: (v) => setOption((o) => o.name = v)),
          MenuTile.toggle(
            title: 'Period predictions',
            subtitle: 'Current cycle start and the next 3 predicted periods',
            value: o.predictions,
            onChanged: (v) => setOption((o) => o.predictions = v),
          ),
          MenuTile.toggle(
            title: 'Fertile window and ovulation',
            value: o.fertility,
            onChanged: (v) => setOption((o) => o.fertility = v),
          ),
          MenuTile.toggle(
            title: 'Current phase and tips',
            value: o.phase,
            onChanged: (v) => setOption((o) => o.phase = v),
          ),
          MenuTile.toggle(
            title: 'Pregnancy progress',
            subtitle: 'Week and due date, in pregnancy mode',
            value: o.pregnancy,
            onChanged: (v) => setOption((o) => o.pregnancy = v),
          ),
          MenuTile.toggle(
            title: 'Recent moods',
            subtitle: 'From the last 3 days. Never shared in pregnancy mode.',
            value: o.moods,
            onChanged: (v) => setOption((o) => o.moods = v),
          ),
          MenuTile.toggle(
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

/// The share card, set as a short letter: a salutation, how to open it, the
/// QR code framed by hairlines, and a signature.
class _CodeCard extends StatelessWidget {
  const _CodeCard({super.key, required this.code, required this.onRegenerate, required this.onStop});
  final String code;
  final VoidCallback onRegenerate;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final snap = PartnerSnapshot.decode(code);
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final age = daysBetween(snap.generated, today());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: MonoLabel('To my partner')),
            MonoLabel(age <= 0 ? 'Snapshot of today' : 'Snapshot of ${fmtShort(snap.generated)}'),
          ],
        ),
        Gap.v12,
        Text('Dear partner,', style: Almanac.italic(context, size: 26)),
        Gap.v8,
        Text(
          'Here is where I am in my cycle. Open Bloom, go to You, then Partner sharing, then I\'m a partner, '
          'and scan or paste this code.',
          style: theme.textTheme.bodyLarge,
        ),
        Gap.v20,
        // The QR, framed by hairlines above and below like a printed plate.
        const Hairline(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xl),
          child: Center(
            child: Container(
              padding: Insets.all12,
              // Scanners need dark modules on a light ground, in both themes.
              color: BloomColors.paper,
              child: QrImageView(
                data: code,
                size: 196,
                padding: EdgeInsets.zero,
                backgroundColor: BloomColors.paper,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: BloomColors.ink),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: BloomColors.ink,
                ),
                semanticsLabel: 'QR code for your partner snapshot',
              ),
            ),
          ),
        ),
        const Hairline(),
        Gap.v8,
        Pressable(
          tooltip: 'Copy code',
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) showSnack(context, 'Code copied');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis, style: Almanac.data(context, size: 11.5)),
                ),
                Gap.h12,
                const MonoLabel('Copy'),
              ],
            ),
          ),
        ),
        Gap.v12,
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            snap.name == null || snap.name!.isEmpty ? 'With love' : '— ${snap.name}',
            style: Almanac.italic(context, size: 18, color: p.ink2),
          ),
        ),
        Gap.v20,
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton(
            label: 'Share code',
            icon: Icons.ios_share,
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text:
                    'Here\'s my Bloom partner code. Open Bloom, go to You > Partner sharing > I\'m a partner, '
                    'and paste it:\n\n$code',
                subject: 'Bloom partner code',
              ),
            ),
          ),
        ),
        Gap.v8,
        Wrap(
          spacing: Space.xl,
          children: [
            InkLink('Update snapshot', onTap: onRegenerate),
            InkLink('Stop sharing', color: BloomColors.error, onTap: onStop),
          ],
        ),
      ],
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

    final input = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snap == null) ...[
          const EmptyState(
            compact: true,
            glyph: Botanical.flower,
            title: 'See your partner\'s cycle',
            body:
                'Paste the code your partner shared from their Bloom app to see their cycle summary and how to '
                'support them.',
          ),
          Gap.v8,
        ] else ...[
          const MonoLabel('A newer letter'),
          Gap.v4,
          Text('Open a newer code', style: theme.textTheme.titleLarge),
          Gap.v8,
        ],
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          style: Almanac.data(context, size: 13, color: BloomColors.of(context).ink),
          decoration: InputDecoration(labelText: 'Partner code', hintText: 'BLOOM1....', errorText: _error),
        ),
        Gap.v16,
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton(label: 'View snapshot', onPressed: () => _open(store)),
        ),
      ],
    );

    return _Stack([
      if (snap != null) ...[
        PartnerView(snapshot: snap),
        Align(
          alignment: Alignment.centerLeft,
          child: InkLink(
            'Remove this snapshot',
            color: BloomColors.of(context).ink2,
            onTap: () {
              state.viewed = null;
              state.save(store);
            },
          ),
        ),
        const Hairline(),
      ],
      input,
    ]);
  }
}

/// Read-only partner view of a snapshot, as a calm editorial page.
class PartnerView extends StatelessWidget {
  const PartnerView({super.key, required this.snapshot});
  final PartnerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final now = today();
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final who = s.name ?? 'Your partner';
    final age = daysBetween(s.generated, now);
    final phase = s.phaseOn(now);
    final next = s.nextPeriodAfter(now);
    final nextOv = s.ovulations.where((o) => !o.isBefore(addDays(now, -1))).firstOrNull;
    final shared = age <= 0 ? 'Shared today' : 'Shared ${fmtShort(s.generated)} · $age day${age == 1 ? '' : 's'} ago';
    final pregnant = s.pregnant && s.dueDate != null;

    Widget hero;
    List<String> tips;
    if (pregnant) {
      final lmp = addDays(s.dueDate!, -280);
      final d = daysBetween(lmp, now).clamp(0, 300);
      final weeks = d ~/ 7;
      tips = partnerPregnancyTips(weeks);
      hero = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(shared),
          Gap.v8,
          PhaseTitle(lead: '$who\'s pregnancy,', italic: 'week $weeks, day ${d % 7}.', color: BloomColors.pregnancy),
          Gap.v8,
          Text(
            'Due around ${fmtFull(s.dueDate!)} · ${daysBetween(now, s.dueDate!)} days to go',
            style: theme.textTheme.bodyLarge!.copyWith(color: p.ink2),
          ),
        ],
      );
    } else {
      tips = phase == null ? const [] : partnerPhaseTips(phase);
      hero = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: MonoLabel(shared)),
              if (phase != null) BotanicalGlyph.phase(phase, size: 26),
            ],
          ),
          Gap.v8,
          PhaseTitle(
            lead: '$who\'s cycle,',
            italic: phase == null ? 'no phase shared.' : '${phase.label.toLowerCase()}.',
            color: phase == null ? null : phaseColor(phase),
          ),
          if (phase != null) ...[
            Gap.v12,
            Text(partnerPhaseSummary(phase), style: theme.textTheme.bodyLarge!.copyWith(color: p.ink2)),
          ],
        ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (next != null)
              Expanded(
                child: StatTile(
                  color: BloomColors.period,
                  value: '${daysBetween(now, next)}',
                  unit: daysBetween(now, next) == 1 ? 'day' : 'days',
                  label: 'Until next period',
                  caption: fmtShort(next),
                ),
              ),
            if (next != null && nextOv != null) Gap.h16,
            if (nextOv != null)
              Expanded(
                child: StatTile(
                  color: BloomColors.fertile,
                  value: fmtShort(addDays(nextOv, -5)),
                  label: 'Fertile window',
                  caption: 'to ${fmtShort(addDays(nextOv, 1))}',
                ),
              ),
          ],
        ),
      if (tips.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('How to support', label: 'Notes', padding: EdgeInsets.zero),
            Gap.v12,
            for (var i = 0; i < tips.length; i++) ...[
              const Hairline(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.md),
                child: Marginalia(
                  label: (i + 1).toString().padLeft(2, '0'),
                  labelWidth: 40,
                  child: Text(tips[i], style: theme.textTheme.bodyMedium),
                ),
              ),
            ],
            const Hairline(),
          ],
        ),
      if (s.moods.isNotEmpty || s.symptoms.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MonoLabel('Recently logged'),
            Gap.v12,
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in s.moods) PillChip(m),
                for (final m in s.symptoms) PillChip(m, color: BloomColors.luteal),
              ],
            ),
          ],
        ),
      if (s.periodStarts.isNotEmpty || s.ovulations.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('The next five weeks', label: 'Almanac', padding: EdgeInsets.zero),
            Gap.v16,
            _MiniCalendar(snapshot: s, from: now),
          ],
        ),
      const Disclaimer(text: 'Predictions are estimates and aren\'t birth control.'),
    ]);
  }
}

/// Five weeks as a printed almanac grid: serif numerals colored by meaning,
/// today underlined in ink.
class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({required this.snapshot, required this.from});
  final PartnerSnapshot snapshot;
  final DateTime from;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final firstDow = context.read<AppStore>().profile.firstDayOfWeek;
    final start = addDays(from, -((from.weekday - firstDow + 7) % 7));
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(child: MonoLabel(DateFormat('E').format(addDays(start, i)).substring(0, 1), size: 10)),
              ),
          ],
        ),
        Gap.v8,
        const Hairline(),
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
                      final isToday = sameDay(d, from);
                      final color = period
                          ? p.period
                          : ov
                          ? p.ovulation
                          : fertile
                          ? p.fertile
                          : d.isBefore(from)
                          ? p.ink2.withValues(alpha: 0.5)
                          : p.ink;
                      return SizedBox(
                        height: 44,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${d.day}',
                              // Fertile days are italic as well as sage, so
                              // the meaning doesn't rest on color alone.
                              style: Almanac.serif(
                                size: 18,
                                weight: ov ? 450 : 340,
                                italic: fertile || ov,
                                color: color,
                                height: 1,
                                tabular: true,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (isToday)
                              Container(width: 14, height: 1.5, color: p.ink)
                            else if (ov)
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(color: p.ovulation, shape: BoxShape.circle),
                              )
                            else
                              const SizedBox(height: 1.5),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        const Hairline(),
        Gap.v12,
        Wrap(
          spacing: Space.lg,
          runSpacing: Space.xs,
          children: [
            _dot(context, p.period, 'Period'),
            _dot(context, p.fertile, 'Fertile, italic'),
            _dot(context, p.ovulation, 'Ovulation, dotted'),
            _dot(context, p.ink, 'Today, underlined'),
          ],
        ),
      ],
    );
  }

  Widget _dot(BuildContext context, Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      MonoLabel(label, size: 10),
    ],
  );
}
