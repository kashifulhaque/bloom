import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/store.dart';
import 'features/sync/sync_setup.dart';
import 'features/updates/update_controller.dart';
import 'features/updates/update_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final sync = createAppSyncController(store);
  final updates = UpdateController.forApp(store);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: updates),
      ],
      child: SyncLifecycle(
        controller: sync,
        child: UpdateLifecycle(controller: updates, child: const BloomApp()),
      ),
    ),
  );
}
