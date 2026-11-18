/// You > Sync: turn on encrypted sync, sign in with an emailed code, save or
/// enter the recovery phrase, and see how sync is doing.
library;

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/sync/sync_controller.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_widgets.dart';

/// The app's [SyncController], or null when none is provided (for example,
/// in widget tests of other screens).
SyncController? watchSync(BuildContext context) {
  try {
    return context.watch<SyncController>();
  } on ProviderNotFoundException {
    return null;
  }
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _top = GlobalKey();
  SyncPhase? _shown;

  /// Each step starts at the top of the page, not where the last one was
  /// scrolled to.
  void _scrollToTopOnStep(SyncPhase phase) {
    if (_shown != null && _shown != phase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _top.currentContext;
        if (ctx == null) return;
        Scrollable.maybeOf(ctx)?.position.animateTo(0, duration: Motion.medium, curve: Motion.curve);
      });
    }
    _shown = phase;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SyncController>().open();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    _scrollToTopOnStep(sync.phase);
    final (subtitle, body) = switch (sync.phase) {
      SyncPhase.unconfigured => ('Not available in this build.', const _Unconfigured()),
      SyncPhase.starting => ('Checking this device…', const _Starting()),
      SyncPhase.signedOut => ('Keep Bloom the same on your phone and the web.', const _Intro()),
      SyncPhase.codeSent => ('Check your email.', const _CodeStep()),
      SyncPhase.needsSetup => ('Your recovery phrase.', const _SetupStep()),
      SyncPhase.needsUnlock => ('Unlock your synced data.', const _UnlockStep()),
      SyncPhase.active => ('End-to-end encrypted.', const _Status()),
    };
    return SettingsPage(
      eyebrow: 'Data & privacy',
      title: 'Sync',
      subtitle: subtitle,
      children: [
        AnimatedSwitcher(
          key: _top,
          duration: Motion.medium,
          switchInCurve: Motion.curve,
          child: KeyedSubtree(key: ValueKey(sync.phase), child: body),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- shared

TextStyle _muted(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(color: BloomColors.of(context).ink2);

/// The last action's error, in the error tone, or nothing.
class _ActionError extends StatelessWidget {
  const _ActionError();

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
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: readableTint(BloomColors.error, Theme.of(context).brightness),
                      ),
                ),
              ),
            ),
    );
  }
}

/// A column of Almanac sections with the standard spacing.
class _Sections extends StatelessWidget {
  const _Sections({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap.v32, children[i]],
        ],
      );
}

class _Point extends StatelessWidget {
  const _Point(this.label, this.title, this.text);
  final String label;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Marginalia(
      label: label,
      labelWidth: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Almanac.serif(size: 18, weight: 380, color: p.ink, height: 1.25)),
          Gap.v4,
          Text(text, style: _muted(context)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- not configured

class _Unconfigured extends StatelessWidget {
  const _Unconfigured();

  @override
  Widget build(BuildContext context) => _Sections(children: [
        const _Point(
          'Offline',
          'This copy of Bloom has no sync',
          'It was built without a sync server, so everything stays on this device. '
              'To move your data, export a backup in You > My data and import it on the other device.',
        ),
        Text(
          'Builds with sync need the SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY settings. '
          'The project README explains how to add them.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]);
}

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.xxl),
        child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 1.5))),
      );
}

// ---------------------------------------------------------------- intro and email

class _Intro extends StatefulWidget {
  const _Intro();

  @override
  State<_Intro> createState() => _IntroState();
}

class _IntroState extends State<_Intro> {
  final _email = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final theme = Theme.of(context);
    final p = BloomColors.of(context);
    return _Sections(children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('How sync works', label: 'I.', padding: EdgeInsets.zero),
          Gap.v16,
          const _Point(
            'Sealed',
            'Encrypted before it leaves',
            'Bloom encrypts every log, note, and setting on this device. The server keeps only ciphertext. '
                'It can\'t read your entries or see which days you logged.',
          ),
          const Hairline(spacing: Space.md),
          const _Point(
            'Phrase',
            'Twelve words unlock it',
            'You get a 12-word recovery phrase. Enter it once on each new device to unlock your data.',
          ),
          const Hairline(spacing: Space.md),
          const _Point(
            'Shared',
            'What the server does see',
            'Your email address, when and how often records change, how many there are, and your IP address. '
                'The server is run by Supabase in Frankfurt.',
          ),
          const Hairline(spacing: Space.md),
          const _Point(
            'Optional',
            'Off until you turn it on',
            'You can sign out or delete the synced copy at any time. Bloom keeps working offline either way.',
          ),
        ],
      ),
      const InfoBanner(
        tone: BannerTone.warning,
        title: 'No phrase, no recovery',
        message: 'Bloom can\'t reset or recover the phrase. If you lose it and every device that has sync on, '
            'your synced data is gone for good. The data on each device stays.',
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Turn on sync', label: 'II.', padding: EdgeInsets.zero),
          Gap.v8,
          Text('Sign in with a 6-digit code sent to your email. There\'s no password.', style: _muted(context)),
          Gap.v12,
          TextField(
            key: const ValueKey('sync-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Email address'),
            onChanged: (_) => setState(() {}),
          ),
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
          Gap.v16,
          Align(
            alignment: Alignment.centerLeft,
            child: InkButton(
              label: 'Email me a code',
              loading: sync.busy,
              onPressed: _valid && _understood ? () => sync.sendCode(_email.text) : null,
            ),
          ),
          const _ActionError(),
        ],
      ),
    ]);
  }
}

class _CodeStep extends StatefulWidget {
  const _CodeStep();

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
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
    return _Sections(children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: 'We sent a code to ', style: _muted(context)),
            TextSpan(text: sync.email ?? 'your email', style: Almanac.mono(size: 14, color: p.ink)),
            TextSpan(text: '. It expires in 10 minutes.', style: _muted(context)),
          ])),
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
            onSubmitted: (_) => ready ? sync.verifyCode(_code.text) : null,
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
          const _ActionError(),
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
      ),
    ]);
  }
}

// ---------------------------------------------------------------- first device

class _SetupStep extends StatefulWidget {
  const _SetupStep();

  @override
  State<_SetupStep> createState() => _SetupStepState();
}

class _SetupStepState extends State<_SetupStep> {
  bool _confirming = false;
  late final RecoveryPhrase _phrase = context.read<SyncController>().beginSetup();

  /// Three word positions (0-based) to check, in order.
  late final List<int> _ask = (List.generate(RecoveryPhrase.wordCount, (i) => i)..shuffle(Random.secure()))
      .take(3)
      .toList()
    ..sort();
  late final _answers = [for (final _ in _ask) TextEditingController()];

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allRight => [
        for (var i = 0; i < _ask.length; i++) _answers[i].text.trim().toLowerCase() == _phrase.words[_ask[i]],
      ].every((ok) => ok);

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    return AnimatedSwitcher(
      duration: Motion.medium,
      child: _confirming ? _confirm(context, sync) : _show(context),
    );
  }

  Widget _show(BuildContext context) => _Sections(
        key: const ValueKey('show'),
        children: [
          Text(
            'This is the first device with sync on this account. Write these 12 words down, in order, '
            'and keep them somewhere safe and offline. Bloom shows them only once.',
            style: _muted(context),
          ),
          _PhraseList(words: _phrase.words),
          const InfoBanner(
            tone: BannerTone.warning,
            title: 'Keep it private',
            message: 'Anyone with these words and access to your email can read your synced data. '
                'Don\'t store them in a screenshot, a chat, or cloud notes.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: InkButton(label: 'I\'ve written it down', onPressed: () => setState(() => _confirming = true)),
          ),
        ],
      );

  Widget _confirm(BuildContext context, SyncController sync) => _Sections(
        key: const ValueKey('confirm'),
        children: [
          Text('To check your copy, enter these three words from your phrase.', style: _muted(context)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _ask.length; i++) ...[
                if (i > 0) Gap.v12,
                TextField(
                  key: ValueKey('sync-confirm-$i'),
                  controller: _answers[i],
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: InputDecoration(labelText: 'Word ${_ask[i] + 1}'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: Space.md,
                runSpacing: Space.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkButton(
                    label: sync.busy ? 'Securing your key…' : 'Turn on sync',
                    loading: sync.busy,
                    onPressed: _allRight ? sync.finishSetup : null,
                  ),
                  InkLink('Show the words again', onTap: sync.busy ? null : () => setState(() => _confirming = false)),
                ],
              ),
              const _ActionError(),
            ],
          ),
        ],
      );
}

/// The 12 words as a numbered list in two columns: mono numerals in the
/// margin and serif words.
class _PhraseList extends StatelessWidget {
  const _PhraseList({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    Widget word(int i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Row(
            children: [
              SizedBox(width: 32, child: Text((i + 1).toString().padLeft(2, '0'), style: Almanac.label(context))),
              Expanded(child: Text(words[i], style: Almanac.serif(size: 20, weight: 380, color: p.ink))),
            ],
          ),
        );
    final half = words.length ~/ 2;
    return Semantics(
      label: 'Recovery phrase: ${[for (var i = 0; i < words.length; i++) '${i + 1}, ${words[i]}'].join('; ')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        decoration: BoxDecoration(border: Border.all(color: p.hairline), borderRadius: Radii.lgAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: [for (var i = 0; i < half; i++) word(i)])),
            Gap.h16,
            Expanded(child: Column(children: [for (var i = half; i < words.length; i++) word(i)])),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- new device

class _UnlockStep extends StatefulWidget {
  const _UnlockStep();

  @override
  State<_UnlockStep> createState() => _UnlockStepState();
}

class _UnlockStepState extends State<_UnlockStep> {
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
    return _Sections(children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sync is already on for ${sync.email ?? 'this account'}. Enter the 12-word recovery phrase '
            'from your first device. Where this device and the account both have an entry, such as the '
            'same day, the account\'s copy is kept. Everything else on this device is added.',
            style: _muted(context),
          ),
          Gap.v16,
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
              label: sync.busy ? 'Unlocking…' : 'Unlock',
              loading: sync.busy,
              onPressed: count == RecoveryPhrase.wordCount ? () => sync.unlock(_phrase.text) : null,
            ),
          ),
          const _ActionError(),
        ],
      ),
      _AccountActions(lostPhrase: true),
    ]);
  }
}

// ---------------------------------------------------------------- status

class _Status extends StatelessWidget {
  const _Status();

  static String _when(DateTime? t) {
    if (t == null) return 'Not yet';
    final ago = DateTime.now().difference(t);
    if (ago.inSeconds < 45) return 'Just now';
    if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
    if (ago.inHours < 24 && t.day == DateTime.now().day) return DateFormat.jm().format(t);
    return DateFormat('MMM d, h:mm a').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final p = BloomColors.of(context);
    return _Sections(children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MonoLabel('Last synced'),
          Gap.v8,
          Text(
            sync.syncing ? 'Syncing…' : _when(sync.lastSyncAt),
            key: const ValueKey('sync-last'),
            style: Almanac.serif(size: 34, weight: 330, color: p.ink, height: 1.1),
          ),
          Gap.v20,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Figure(value: '${sync.recordCount}', label: 'Records')),
                VerticalDivider(width: Space.xxl, thickness: 1, color: p.hairline),
                Expanded(child: _Figure(value: '${sync.pendingCount}', label: 'Waiting to send')),
              ],
            ),
          ),
          if (sync.syncError != null) ...[
            Gap.v20,
            InfoBanner(
              key: const ValueKey('sync-error'),
              tone: BannerTone.error,
              title: 'Last sync didn\'t finish',
              message: '${sync.syncError} Your data on this device is safe. Bloom tries again later.',
            ),
          ],
          Gap.v20,
          Align(
            alignment: Alignment.centerLeft,
            child: InkButton(label: 'Sync now', loading: sync.syncing, onPressed: sync.syncNow),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Account', padding: EdgeInsets.zero),
          Gap.v16,
          Marginalia(
            label: 'Email',
            labelWidth: 88,
            child: Text(sync.email ?? '—', style: Almanac.mono(size: 14, color: p.ink)),
          ),
          const Hairline(spacing: Space.md),
          const _Point(
            'Sealed',
            'Encrypted on this device',
            'Logs, notes, settings, and dates are encrypted before upload. Your app-lock PIN and AI key stay '
                'on this device.',
          ),
        ],
      ),
      const _AccountActions(lostPhrase: false),
    ]);
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel(label, size: 10),
            Gap.v8,
            Text(value, style: Almanac.numeral(context, size: 32, weight: 320)),
          ],
        ),
      );
}

/// Sign out, and delete the synced copy.
class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.lostPhrase});

  /// Words the delete section for someone who lost their phrase.
  final bool lostPhrase;

  Future<void> _delete(BuildContext context) async {
    final sync = context.read<SyncController>();
    final ok = await showDialog<bool>(context: context, builder: (_) => const _DeleteSyncedDialog());
    if (ok != true) return;
    await sync.deleteSyncedData();
    if (context.mounted && sync.actionError == null) showSnack(context, 'Synced data deleted');
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkButton.outlined(label: 'Sign out', onPressed: sync.busy ? null : sync.signOut),
        ),
        Gap.v8,
        Text(
          'Signing out turns sync off on this device and removes its copy of the key. '
          'Your data stays here and in your account.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Gap.v32,
        DangerSection(
          title: 'Delete synced data',
          body: lostPhrase
              ? 'Lost the phrase? Delete the synced copy and the account, then turn sync on again to start over '
                  'with this device\'s data. This can\'t be undone.'
              : 'Permanently delete your account and everything synced to it from the server. Data on your '
                  'devices stays. This can\'t be undone.',
          action: Align(
            alignment: Alignment.centerLeft,
            child: InkButton.outlined(
              label: 'Delete synced data',
              color: BloomColors.error,
              onPressed: sync.busy ? null : () => _delete(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteSyncedDialog extends StatefulWidget {
  const _DeleteSyncedDialog();

  @override
  State<_DeleteSyncedDialog> createState() => _DeleteSyncedDialogState();
}

class _DeleteSyncedDialogState extends State<_DeleteSyncedDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim() == 'DELETE';
    return AlertDialog(
      title: const Text('Delete synced data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This deletes your sync account and every encrypted record on the server. Other devices stop '
            'syncing. Data on each device stays. It can\'t be undone.',
          ),
          Gap.v16,
          Text('Type DELETE to confirm.', style: Almanac.label(context)),
          Gap.v8,
          TextField(
            key: const ValueKey('sync-delete-confirm'),
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'DELETE'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        InkButton(
          label: 'Delete',
          dense: true,
          color: BloomColors.error,
          onPressed: ready ? () => Navigator.pop(context, true) : null,
        ),
      ],
    );
  }
}
