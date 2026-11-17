/// The PIN screen shown while the app lock is engaged.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'pin_hash.dart';
import 'pin_pad.dart';
import 'settings_widgets.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  Future<void> _forgot(BuildContext context) async {
    final store = context.read<AppStore>();
    final first = await confirmDialog(
      context,
      title: 'Forgot your PIN?',
      message:
          'Bloom keeps your data only on this device, so there\'s no way to recover the PIN. '
          'You can erase all Bloom data and start over. If you have a backup file, you can import it afterward.',
      confirm: 'Erase data',
      destructive: true,
    );
    if (!first || !context.mounted) return;
    final second = await confirmDialog(
      context,
      title: 'Erase everything?',
      message:
          'This permanently deletes your periods, logs, settings, and PIN from this device. '
          'It can\'t be undone.',
      confirm: 'Erase all data',
      destructive: true,
    );
    if (second) await store.deleteAll();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: BloomGradients.dusk),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: Insets.all24,
              child: PinPad(
                onGradient: true,
                header: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Space.sm),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
                      child: const BloomLogo(size: 64),
                    ),
                    Gap.v12,
                    Text('Bloom', style: theme.textTheme.titleLarge!.copyWith(color: Colors.white)),
                  ],
                ),
                title: 'Enter your PIN',
                subtitle: 'Bloom is locked to keep your data private',
                onCompleted: (pin) {
                  if (verifyPin(pin, store.profile.pin)) {
                    store.unlock();
                    return null;
                  }
                  return 'Wrong PIN. Try again.';
                },
                footer: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _forgot(context),
                  child: const Text('Forgot PIN?'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
