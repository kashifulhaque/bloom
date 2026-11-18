/// Sign-in pieces shared by You > Sync and the onboarding restore flow: the
/// email form, the code step, and the recovery-phrase form. Both flows drive
/// the same [SyncController], so signing in looks the same afterward.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/sync/sync_controller.dart';
import '../../widgets/widgets.dart';

TextStyle syncMuted(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2);

/// The last action's error, in the error tone, or nothing.
class SyncActionError extends StatelessWidget {
  const SyncActionError({super.key});

  @override
  Widget build(BuildContext context) {
    final error = context.select<SyncController, String?>((s) => s.actionError);
    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.curve,
      child: error == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: const ValueKey('sync-action-error'),
                  style: Theme.of(context).textTheme.bodyMedium!
                      .copyWith(color: readableTint(BloomColors.error, Theme.of(context).brightness)),
                ),
              ),
            ),
    );
  }
}

/// The email field and **Email me a code**.
class SyncEmailForm extends StatefulWidget {
  const SyncEmailForm({super.key, this.acknowledge = false});

  /// Asks the user to confirm that only the recovery phrase unlocks synced
  /// data before a code is sent. You > Sync asks; restoring an account,
  /// which already has a phrase, doesn't.
  final bool acknowledge;

  @override
  State<SyncEmailForm> createState() => _SyncEmailFormState();
}

class _SyncEmailFormState extends State<SyncEmailForm> {
  final _email = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  bool get _ready => _valid && (_understood || !widget.acknowledge);

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('sync-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Email address'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _ready && !sync.busy ? sync.sendCode(_email.text) : null,
        ),
        if (widget.acknowledge) ...[
          Gap.v16,
          Pressable(
            onTap: () => setState(() => _understood = !_understood),
            semanticLabel: 'I understand that only my recovery phrase can unlock synced data',
            selected: _understood,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Checkbox(
                    key: const ValueKey('sync-understood'),
                    value: _understood,
                    onChanged: (v) => setState(() => _understood = v ?? false),
                  ),
                ),
                Gap.h8,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: Text(
                      'I understand that only my recovery phrase can unlock synced data.',
                      style: theme.textTheme.bodyMedium!.copyWith(color: p.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Gap.v16,
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton(
            label: 'Email me a code',
            loading: sync.busy,
            onPressed: _ready ? () => sync.sendCode(_email.text) : null,
          ),
        ),
        const SyncActionError(),
      ],
    );
  }
}

/// The 6-digit code step: the code field, **Sign in**, and links to send a
/// new code or use a different email.
class SyncCodeForm extends StatefulWidget {
  const SyncCodeForm({super.key});

  @override
  State<SyncCodeForm> createState() => _SyncCodeFormState();
}

class _SyncCodeFormState extends State<SyncCodeForm> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final p = BloomColors.of(context);
    final ready = _code.text.trim().length == 6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'We sent a code to ', style: syncMuted(context)),
              TextSpan(
                text: sync.email ?? 'your email',
                style: Almanac.mono(size: 14, color: p.ink),
              ),
              TextSpan(text: '. It expires in 10 minutes.', style: syncMuted(context)),
            ],
          ),
        ),
        Gap.v16,
        TextField(
          key: const ValueKey('sync-code'),
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: Almanac.mono(size: 24, color: p.ink, letterSpacing: 6),
          decoration: const InputDecoration(labelText: '6-digit code'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => ready && !sync.busy ? sync.verifyCode(_code.text) : null,
        ),
        Gap.v20,
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton(
            label: 'Sign in',
            loading: sync.busy,
            onPressed: ready ? () => sync.verifyCode(_code.text) : null,
          ),
        ),
        const SyncActionError(),
        Gap.v20,
        Wrap(
          spacing: Space.xxl,
          runSpacing: Space.sm,
          children: [
            InkLink('Send a new code', onTap: sync.busy ? null : () => sync.sendCode(sync.email!)),
            InkLink('Use a different email', onTap: sync.busy ? null : sync.changeEmail),
          ],
        ),
      ],
    );
  }
}

/// The 12-word recovery phrase field and its submit button.
class SyncPhraseForm extends StatefulWidget {
  const SyncPhraseForm({super.key, required this.label, required this.busyLabel, required this.onSubmit});

  final String label;

  /// The button label while [SyncController.busy].
  final String busyLabel;

  /// Called with the phrase as typed.
  final void Function(SyncController sync, String phrase) onSubmit;

  @override
  State<SyncPhraseForm> createState() => _SyncPhraseFormState();
}

class _SyncPhraseFormState extends State<SyncPhraseForm> {
  final _phrase = TextEditingController();

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final count = RecoveryPhrase.normalize(_phrase.text).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('sync-phrase'),
          controller: _phrase,
          minLines: 3,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          keyboardType: TextInputType.visiblePassword,
          decoration: InputDecoration(labelText: 'Recovery phrase', helperText: '$count of 12 words'),
          onChanged: (_) => setState(() {}),
        ),
        Gap.v20,
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton(
            label: sync.busy ? widget.busyLabel : widget.label,
            loading: sync.busy,
            onPressed: count == RecoveryPhrase.wordCount ? () => widget.onSubmit(sync, _phrase.text) : null,
          ),
        ),
        const SyncActionError(),
      ],
    );
  }
}
