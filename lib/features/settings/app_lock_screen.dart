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
    return SettingsPage(
      eyebrow: 'Settings · App lock',
      title: 'App lock',
      subtitle: on
          ? 'Bloom asks for your PIN when it opens, and again after a minute in the background.'
          : 'Ask for a 4-digit PIN whenever Bloom opens.',
      header: AnimatedSwitcher(
        duration: Motion.medium,
        child: PhaseTitle(key: ValueKey(on), lead: 'The lock is', italic: on ? 'on.' : 'off.', breakLine: false),
      ),
      children: [
        if (!on)
          Align(
            alignment: Alignment.centerLeft,
            child: InkButton(label: 'Set a PIN', onPressed: () => _push(context, PinSetupMode.set)),
          )
        else
          MenuSection(
            children: [
              IndexEntry(title: 'Change PIN', onTap: () => _push(context, PinSetupMode.change)),
              IndexEntry(
                title: 'Lock now',
                subtitle: 'Close the notebook until you enter your PIN',
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  store.lock();
                },
              ),
              IndexEntry(
                title: 'Turn off PIN lock',
                color: BloomColors.error,
                onTap: () => _push(context, PinSetupMode.remove),
              ),
            ],
          ),
        const Marginalia(
          label: 'Note',
          child: Text(
            'Your PIN is stored on this device as a salted hash, which hides it but isn\'t strong encryption. '
            'If you forget it, the only way back in is to erase Bloom\'s data, so keep a backup from My data.',
          ),
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
          Gap.v8,
          Center(
            child: PinPad(
              title: title,
              subtitle: subtitle,
              onCompleted: _onPin,
              header: Column(
                children: [
                  const BloomLogo(size: 44),
                  Gap.v16,
                  MonoLabel(steps.length > 1 ? 'Step ${index + 1} of ${steps.length}' : 'App lock'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
