import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/store.dart';
import '../../widgets/widgets.dart';
import 'pin_hash.dart';
import 'pin_pad.dart';
import 'settings_widgets.dart';

/// App lock settings: set, change, or remove the 4-digit PIN.
class AppLockSettingsScreen extends StatelessWidget {
  const AppLockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final on = store.profile.pin != null;
    final theme = Theme.of(context);
    final c = on ? BloomColors.success : BloomColors.luteal;
    return SettingsPage(
      title: 'App lock',
      children: [
        BloomCard.tinted(
          color: c,
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: Motion.medium,
                child: IconBadge(
                  key: ValueKey(on),
                  icon: on ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: c,
                  size: 56,
                  filled: true,
                ),
              ),
              Gap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(on ? 'PIN lock is on' : 'PIN lock is off', style: theme.textTheme.titleLarge),
                    Gap.v4,
                    Text(
                      on
                          ? 'Bloom asks for your PIN when it opens, and again after a minute in the background.'
                          : 'Ask for a 4-digit PIN whenever Bloom opens.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!on)
          GradientButton(label: 'Set a PIN', icon: Icons.pin_rounded, onPressed: () => _push(context, PinSetupMode.set))
        else
          MenuSection(
            children: [
              MenuTile(
                icon: Icons.edit_rounded,
                color: BloomColors.info,
                title: 'Change PIN',
                onTap: () => _push(context, PinSetupMode.change),
              ),
              MenuTile(
                icon: Icons.lock_clock_rounded,
                color: BloomColors.luteal,
                title: 'Lock now',
                showChevron: false,
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  store.lock();
                },
              ),
              MenuTile(
                icon: Icons.no_encryption_rounded,
                title: 'Turn off PIN lock',
                destructive: true,
                onTap: () => _push(context, PinSetupMode.remove),
              ),
            ],
          ),
        const InfoBanner(
          tone: BannerTone.info,
          message:
              'Your PIN is stored on this device as a salted hash, which hides it but isn\'t strong encryption. '
              'If you forget it, the only way back in is to erase Bloom\'s data, so keep a backup from My data.',
        ),
      ],
    );
  }

  void _push(BuildContext context, PinSetupMode mode) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PinSetupScreen(mode: mode)));
}

enum PinSetupMode { set, change, remove }

/// Walks through verifying the current PIN and entering a new one twice.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.mode});
  final PinSetupMode mode;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Step { current, enter, confirm }

class _PinSetupScreenState extends State<PinSetupScreen> {
  late _Step _step = widget.mode == PinSetupMode.set ? _Step.enter : _Step.current;
  String _first = '';

  String? _onPin(String pin) {
    final store = context.read<AppStore>();
    switch (_step) {
      case _Step.current:
        if (!verifyPin(pin, store.profile.pin)) return 'Wrong PIN. Try again.';
        if (widget.mode == PinSetupMode.remove) {
          store.updateProfile((p) => p.pin = null);
          _done('PIN lock turned off');
          return null;
        }
        setState(() => _step = _Step.enter);
        return null;
      case _Step.enter:
        _first = pin;
        setState(() => _step = _Step.confirm);
        return null;
      case _Step.confirm:
        if (pin != _first) {
          setState(() => _step = _Step.enter);
          return 'PINs didn\'t match. Start again.';
        }
        store.updateProfile((p) => p.pin = hashPin(pin));
        _done(widget.mode == PinSetupMode.set ? 'PIN lock is on' : 'PIN changed');
        return null;
    }
  }

  void _done(String message) {
    showSnack(context, message);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _Step.current => (
        'Enter your current PIN',
        widget.mode == PinSetupMode.remove ? 'Confirm it\'s you to turn off the lock.' : 'Confirm it\'s you first.',
      ),
      _Step.enter => ('Choose a new PIN', 'Pick 4 digits that are easy for you to remember.'),
      _Step.confirm => ('Confirm your new PIN', 'Enter the same 4 digits again.'),
    };
    final steps = widget.mode == PinSetupMode.set
        ? const [_Step.enter, _Step.confirm]
        : widget.mode == PinSetupMode.change
        ? const [_Step.current, _Step.enter, _Step.confirm]
        : const [_Step.current];
    final index = steps.indexOf(_step);
    return Scaffold(
      body: BloomPage(
        children: [
          Gap.v24,
          Center(
            child: PinPad(
              title: title,
              subtitle: subtitle,
              onCompleted: _onPin,
              header: Column(
                children: [
                  IconBadge(
                    icon: _step == _Step.confirm ? Icons.verified_rounded : Icons.pin_rounded,
                    color: BloomColors.brand,
                    size: 64,
                  ),
                  if (steps.length > 1) ...[
                    Gap.v16,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          AnimatedContainer(
                            duration: Motion.medium,
                            curve: Motion.curve,
                            margin: const EdgeInsets.symmetric(horizontal: Space.xs),
                            width: i == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: Radii.pillAll,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: i <= index ? 1 : 0.2),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
