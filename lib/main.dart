import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/store.dart';
import 'features/sync/sync_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final sync = createAppSyncController(store);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: SyncLifecycle(controller: sync, child: const BloomApp()),
    ),
  );
}
