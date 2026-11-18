import 'package:web/web.dart' as web;

/// Reloads the tab. nginx serves `index.html` and `flutter_bootstrap.js`
/// with `no-cache`, and Flutter's service worker only unregisters itself,
/// so the reload loads the newest deployed build.
void reloadPage() => web.window.location.reload();
