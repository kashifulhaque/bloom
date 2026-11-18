/// The day strip: [Ledger] and [LedgerDay].
library;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/dates.dart';
import '../theme/app_theme.dart';
import 'ink.dart';

/// How one day looks in a [Ledger].
@immutable
class LedgerDay {
  const LedgerDay({this.color, this.predicted = false, this.dot, this.semanticLabel});

  /// No meaning: plain ink numeral.
  static const plain = LedgerDay();

  /// Numeral color, usually a phase color (period, fertile). Null is ink.
  final Color? color;

  /// A prediction rather than a logged fact: the numeral turns italic and
  /// lighter, with a dotted rule under it.
  final bool predicted;

  /// A small dot under the numeral, for example "has a log entry".
  final Color? dot;

  /// Extra screen reader text, such as "period" or "fertile".
  final String? semanticLabel;
}

/// A horizontal strip of days, like a line in a ledger: a mono weekday
/// letter above a serif numeral, colored by meaning, with an ink underline
/// under today and a hairline box around the selected day.
///
/// It's generic: you pass the days and a function that styles each one.
///
/// ```dart
/// Ledger(
///   days: [for (var i = -3; i <= 3; i++) addDays(today(), i)],
///   today: today(),
///   selected: _day,
///   styleFor: (d) {
///     final info = store.engine.info(d);
///     if (store.isPeriodDay(d)) return const LedgerDay(color: BloomColors.period);
///     if (info.isFertile) return const LedgerDay(color: BloomColors.fertile);
///     return LedgerDay.plain;
///   },
///   onTap: (d) => setState(() => _day = d),
/// )
/// ```
class Ledger extends StatelessWidget {
  const Ledger({
    super.key,
    required this.days,
    required this.styleFor,
    this.onTap,
    this.today,
    this.selected,
    this.numeralSize = 20,
  });

  final List<DateTime> days;

  /// Styles each day. Return [LedgerDay.plain] for a plain day.
  final LedgerDay Function(DateTime day) styleFor;

  /// Called when a day is tapped. Null makes the strip read-only.
  final ValueChanged<DateTime>? onTap;

  /// The day to underline. Defaults to the real today.
  final DateTime? today;

  /// The day to box.
  final DateTime? selected;

  final double numeralSize;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    final t = dayOf(today ?? DateTime.now());
    final sel = selected == null ? null : dayOf(selected!);
    final letter = DateFormat.E();
    final long = DateFormat.MMMMEEEEd();
    return Row(
      children: [
        for (final d in days.map(dayOf))
          Expanded(
            child: Builder(builder: (context) {
              final style = styleFor(d);
              final isToday = d == t;
              final isSel = d == sel;
              final c = style.color == null ? p.ink : BloomColors.resolve(context, style.color!);
              final numStyle = Almanac.serif(
                size: numeralSize,
                weight: isToday ? 450 : 380,
                italic: style.predicted,
                color: style.predicted ? c.withValues(alpha: 0.7) : c,
                height: 1.1,
                tabular: true,
              );
              final cell = AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.curve,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                decoration: BoxDecoration(
                  borderRadius: Radii.mdAll,
                  border: Border.all(color: isSel ? p.hairline : Colors.transparent),
                  color: isSel ? p.raised.withValues(alpha: 0.6) : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(letter.format(d).substring(0, 1), style: Almanac.label(context, size: 10.5)),
                    const SizedBox(height: 5),
                    Text('${d.day}', style: numStyle),
                    const SizedBox(height: 3),
                    // Today: a solid ink underline. Predicted: a dotted rule.
                    SizedBox(
                      height: 2,
                      width: numeralSize * 1.2,
                      child: isToday
                          ? ColoredBox(color: p.ink)
                          : style.predicted
                              ? CustomPaint(painter: _DottedRule(c.withValues(alpha: 0.7)))
                              : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 4,
                      child: style.dot == null
                          ? null
                          : Container(
                              width: 4,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: BloomColors.resolve(context, style.dot!)),
                            ),
                    ),
                  ],
                ),
              );
              final label = [
                long.format(d),
                if (isToday) 'today',
                if (style.semanticLabel != null) style.semanticLabel!,
                if (style.predicted) 'predicted',
              ].join(', ');
              return Semantics(
                label: label,
                selected: isSel,
                button: onTap != null,
                excludeSemantics: true,
                child: onTap == null ? cell : Pressable(onTap: () => onTap!(d), borderRadius: Radii.mdAll, child: cell),
              );
            }),
          ),
      ],
    );
  }
}

class _DottedRule extends CustomPainter {
  _DottedRule(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 1.0; x < size.width; x += 4) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.75, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedRule old) => old.color != color;
}
