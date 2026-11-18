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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xxl),
            child: PinPad(
              header: const Column(
                children: [
                  BloomLogo(size: 56),
                  Gap.v16,
                  MonoLabel('Bloom is locked'),
                ],
              ),
              title: 'Welcome back',
              subtitle: 'Enter your PIN to open your notebook.',
              onCompleted: (pin) {
                if (verifyPin(pin, store.profile.pin)) {
                  store.unlock();
                  return null;
                }
                return 'Wrong PIN. Try again.';
              },
              footer: InkLink('Forgot PIN?', size: 13.5, color: BloomColors.of(context).ink2, onTap: () => _forgot(context)),
            ),
          ),
        ),
      ),
    );
  }
}
