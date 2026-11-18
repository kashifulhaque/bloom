import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';

const kPinLength = 4;

/// A 4-digit PIN entry: four hairline underscores that fill with ink dots,
/// a keypad of serif numerals, keyboard input, and a gentle shake when
/// [onCompleted] rejects the PIN.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.subtitle,
    this.footer,
    this.header,
    this.onGradient = false,
  });

  final String title;
  final String? subtitle;

  /// Called with the full PIN. Return null to accept, or an error message
  /// to shake and clear the dots.
  final String? Function(String pin) onCompleted;
  final Widget? footer;

  /// Shown above the title, for example an icon or logo.
  final Widget? header;

  /// Ignored in Almanac (the pad is always ink on paper); kept for older
  /// code.
  final bool onGradient;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title) _pin = '';
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _add(String d) {
    if (_pin.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == kPinLength) {
      final entered = _pin;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        final err = widget.onCompleted(entered);
        if (!mounted) return;
        setState(() {
          _pin = '';
          _error = err;
        });
        if (err != null) {
          HapticFeedback.mediumImpact();
          _shake.forward(from: 0);
        }
      });
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _add(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    final errorColor = readableTint(BloomColors.error, theme.brightness);

    Widget key(String k, double w) {
      if (k.isEmpty) return SizedBox(width: w, height: 64);
      if (k == '<') {
        return SizedBox(
          width: w,
          height: 64,
          child: Pressable(
            onTap: _pin.isEmpty ? null : _back,
            tooltip: 'Delete',
            semanticLabel: 'Delete',
            borderRadius: Radii.mdAll,
            child: Center(
              child: Icon(
                Icons.backspace_outlined,
                size: 22,
                color: _pin.isEmpty ? p.ink2.withValues(alpha: 0.35) : p.ink2,
              ),
            ),
          ),
        );
      }
      return SizedBox(
        width: w,
        height: 64,
        child: Pressable(
          onTap: () => _add(k),
          pressedOpacity: 0.35,
          borderRadius: Radii.mdAll,
          child: Center(
            child: Text(k, style: Almanac.numeral(context, size: 34, weight: 320)),
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.header != null) ...[widget.header!, Gap.v24],
            AnimatedSwitcher(
              duration: Motion.medium,
              child: Column(
                key: ValueKey(widget.title),
                children: [
                  Text(widget.title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                  if (widget.subtitle != null) ...[
                    Gap.v8,
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium!.copyWith(color: p.ink2),
                    ),
                  ],
                ],
              ),
            ),
            Gap.v32,
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) => Transform.translate(
                offset: Offset(math.sin(_shake.value * math.pi * 4) * 7 * (1 - _shake.value), 0),
                child: child,
              ),
              child: Semantics(
                label: '${_pin.length} of $kPinLength digits entered',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < kPinLength; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                        child: SizedBox(
                          width: 32,
                          height: 28,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedScale(
                                duration: Motion.fast,
                                curve: Motion.curve,
                                scale: i < _pin.length ? 1 : 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.ink),
                                ),
                              ),
                              Gap.v8,
                              AnimatedContainer(
                                duration: Motion.medium,
                                height: 1.5,
                                color: _error != null
                                    ? errorColor
                                    : (i < _pin.length ? p.ink : p.ink2.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: Center(
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  child: _error == null
                      ? const SizedBox.shrink()
                      : Text(
                          _error!,
                          key: ValueKey(_error),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium!.copyWith(color: errorColor),
                        ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                final w = ((box.maxWidth - Space.lg * 2) / 3).clamp(56.0, 88.0);
                return Column(
                  children: [
                    for (final row in const [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['', '0', '<'],
                    ])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [for (final k in row) key(k, w)],
                      ),
                  ],
                );
              },
            ),
            if (widget.footer != null) ...[Gap.v16, widget.footer!],
          ],
        ),
      ),
    );
  }
}
