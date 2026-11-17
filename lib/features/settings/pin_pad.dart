import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/widgets.dart';

const kPinLength = 4;

/// A 4-digit PIN entry with dots, a number pad, keyboard input, and a shake
/// animation when [onCompleted] rejects the PIN.
///
/// Set [onGradient] when the pad sits on a dark or colorful gradient: text
/// and keys turn white.
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
    final tokens = BloomTokens.of(context);
    final g = widget.onGradient;
    final fg = g ? Colors.white : theme.colorScheme.onSurface;
    final muted = g ? Colors.white.withValues(alpha: 0.82) : tokens.muted;
    final accent = g ? Colors.white : theme.colorScheme.primary;
    final errorColor = g ? Colors.white : theme.colorScheme.error;
    final keyBg = g
        ? Colors.white.withValues(alpha: 0.16)
        : (theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHigh : Colors.white);
    final keyBorder = g ? Colors.white.withValues(alpha: 0.22) : tokens.border;

    Widget key(String k, double size) {
      if (k.isEmpty) return SizedBox(width: size, height: size);
      if (k == '<') {
        return SizedBox(
          width: size,
          height: size,
          child: IconButton(
            tooltip: 'Delete',
            onPressed: _pin.isEmpty ? null : _back,
            color: fg,
            disabledColor: muted.withValues(alpha: 0.4),
            icon: const Icon(Icons.backspace_rounded, size: 26),
          ),
        );
      }
      return SizedBox(
        width: size,
        height: size,
        child: Material(
          color: keyBg,
          shape: CircleBorder(side: BorderSide(color: keyBorder)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _add(k),
            splashColor: accent.withValues(alpha: 0.2),
            child: Center(
              child: Text(
                k,
                style: theme.textTheme.headlineMedium!.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
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
            if (widget.header != null) ...[widget.header!, Gap.v20],
            AnimatedSwitcher(
              duration: Motion.medium,
              child: Column(
                key: ValueKey(widget.title),
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.headlineSmall!.copyWith(color: fg),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.subtitle != null) ...[
                    Gap.v8,
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium!.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            Gap.v32,
            AnimatedBuilder(
              animation: _shake,
              builder: (context, child) => Transform.translate(
                offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0),
                child: child,
              ),
              child: Semantics(
                label: '${_pin.length} of $kPinLength digits entered',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < kPinLength; i++)
                      SizedBox(
                        width: 36,
                        height: 20,
                        child: Center(
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            curve: Motion.spring,
                            width: i < _pin.length ? 18 : 14,
                            height: i < _pin.length ? 18 : 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < _pin.length ? accent : Colors.transparent,
                              border: Border.all(
                                color: _error != null
                                    ? errorColor
                                    : (i < _pin.length ? accent : muted.withValues(alpha: 0.6)),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: Center(
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  child: _error == null
                      ? const SizedBox.shrink()
                      : Row(
                          key: ValueKey(_error),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_rounded, size: 18, color: errorColor),
                            Gap.h8,
                            Flexible(
                              child: Text(_error!, style: theme.textTheme.labelLarge!.copyWith(color: errorColor)),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, box) {
                // 76 px keys, shrinking on very narrow screens.
                final size = ((box.maxWidth - Space.lg * 2) / 3).clamp(48.0, 76.0);
                return Column(
                  children: [
                    for (final row in const [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['', '0', '<'],
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [for (final k in row) key(k, size)],
                        ),
                      ),
                  ],
                );
              },
            ),
            if (widget.footer != null) ...[Gap.v12, widget.footer!],
          ],
        ),
      ),
    );
  }
}
