/// **Already have an account?** on the welcome page: sign in with an emailed
/// code, enter the recovery phrase, and restore the synced data, skipping the
/// onboarding questions.
///
/// It drives the app's [SyncController] with the same sign-in steps as
/// You > Sync, so afterward sync is on exactly as if it had been turned on
/// there. Back, at any step, signs out and returns to the welcome page with
/// nothing changed.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/sync/sync_controller.dart';
import '../../widgets/widgets.dart';
import '../sync/sync_steps.dart';

class RestoreFlow extends StatefulWidget {
  const RestoreFlow({super.key, required this.onCancel, required this.onContinueOnboarding});

  /// Returns to the welcome page. Sign-in is already undone.
  final VoidCallback onCancel;

  /// Leaves for the onboarding questions. With [setUpSync], onboarding opens
  /// sync setup, with a new recovery phrase, when it finishes.
  final void Function({required bool setUpSync}) onContinueOnboarding;

  @override
  State<RestoreFlow> createState() => _RestoreFlowState();
}

class _RestoreFlowState extends State<RestoreFlow> {
  /// Showing "I lost my phrase".
  bool _lost = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SyncController>().open();
    });
  }

  Future<void> _cancel() async {
    final sync = context.read<SyncController>();
    if (sync.busy) return;
    if (sync.phase == SyncPhase.active) {
      await sync.signOut();
    } else {
      await sync.cancelSignIn();
    }
    if (mounted) widget.onCancel();
  }

  Future<void> _startFresh() async {
    await context.read<SyncController>().cancelSignIn();
    if (mounted) widget.onContinueOnboarding(setUpSync: false);
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncController>();
    final p = BloomColors.of(context);
    final step = switch (sync.phase) {
      SyncPhase.needsUnlock when _lost => 'lost',
      final phase => phase.name,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Space.maxContentWidth),
              child: Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.gutter, 0),
                      child: Row(
                        children: [
                          IconButton(
                            key: const ValueKey('restore-back'),
                            tooltip: 'Back',
                            onPressed: sync.busy ? null : _cancel,
                            icon: Icon(Icons.arrow_back, size: 20, color: p.ink),
                          ),
                          const Spacer(),
                          const MonoLabel('Restore'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
                      child: AnimatedSwitcher(
                        duration: Motion.medium,
                        switchInCurve: Motion.curve,
                        layoutBuilder: (current, previous) =>
                            Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                        child: KeyedSubtree(key: ValueKey(step), child: _body(context, sync)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SyncController sync) {
    final email = sync.email ?? 'this email';
    return switch (sync.phase) {
      SyncPhase.unconfigured || SyncPhase.starting => const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.xxl),
        child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 1.5))),
      ),
      SyncPhase.signedOut => _Page(
        eyebrow: 'Welcome back',
        title: 'Sign in to restore your data.',
        sub: 'Use the email you turned on sync with. Bloom sends a 6-digit code. There\'s no password.',
        children: const [SyncEmailForm()],
      ),
      SyncPhase.codeSent => const _Page(
        eyebrow: 'Welcome back',
        title: 'Check your email.',
        children: [SyncCodeForm()],
      ),
      SyncPhase.needsSetup => _Page(
        eyebrow: 'Nothing to restore',
        title: 'This account has no synced data.',
        sub: 'Sync was never turned on for $email, so there\'s nothing to bring back.',
        children: [
          Text(
            'You can set up Bloom as new instead. When you finish, Bloom turns on sync for this email and '
            'shows you a new recovery phrase to write down.',
            style: syncMuted(context),
          ),
          Gap.v24,
          Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              InkButton(label: 'Set up a new account', onPressed: () => widget.onContinueOnboarding(setUpSync: true)),
              InkButton.outlined(label: 'Go back', onPressed: sync.busy ? null : _cancel),
            ],
          ),
        ],
      ),
      SyncPhase.needsUnlock when _lost => _Page(
        eyebrow: 'Lost phrase',
        title: 'The phrase is the only key.',
        children: [
          const InfoBanner(
            tone: BannerTone.warning,
            title: 'Encrypted data can\'t be recovered',
            message:
                'Your synced data is encrypted with your recovery phrase before it leaves your device. '
                'Nobody, including Bloom, can reset the phrase or read the data without it.',
          ),
          Gap.v20,
          Text(
            'If you still have a device with sync on, it has all your data: export a backup from '
            'You > My data there instead. Otherwise, you can start fresh on this device. To sync with '
            '$email again later, delete the old synced copy in You > Sync first.',
            style: syncMuted(context),
          ),
          Gap.v24,
          Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkButton(label: 'Start fresh', onPressed: sync.busy ? null : _startFresh),
              InkLink('I found my phrase', onTap: () => setState(() => _lost = false)),
            ],
          ),
        ],
      ),
      SyncPhase.needsUnlock => _Page(
        eyebrow: 'Recovery phrase',
        title: 'Enter your 12 words.',
        sub: 'The recovery phrase you wrote down when you turned on sync for $email.',
        children: [
          SyncPhraseForm(label: 'Restore', busyLabel: 'Restoring…', onSubmit: (sync, phrase) => sync.restore(phrase)),
          Gap.v20,
          Align(
            alignment: Alignment.centerLeft,
            child: InkLink('I lost my phrase', onTap: sync.busy ? null : () => setState(() => _lost = true)),
          ),
        ],
      ),
      // Restored, but the account had no profile, so onboarding is still open.
      SyncPhase.active => _Page(
        eyebrow: 'Sync is on',
        title: 'Your account is empty.',
        sub:
            'Sync is on for $email, but nothing was saved to it yet. Answer a few questions to set up '
            'Bloom, and your answers sync to the account.',
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkButton(label: 'Continue', onPressed: () => widget.onContinueOnboarding(setUpSync: false)),
          ),
        ],
      ),
    };
  }
}

/// One step: a mono eyebrow, a large serif title, a quiet explanation, and
/// the step's content, as on the onboarding pages.
class _Page extends StatelessWidget {
  const _Page({required this.eyebrow, required this.title, this.sub, required this.children});

  final String eyebrow;
  final String title;
  final String? sub;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = BloomColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonoLabel(eyebrow),
              Gap.v12,
              Text(title, style: Almanac.serif(size: 34, weight: 340, color: p.ink, height: 1.12)),
              if (sub != null) ...[
                Gap.v12,
                Text(sub!, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: p.ink2)),
              ],
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}
