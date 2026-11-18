/// Build-time sync settings, passed with `--dart-define-from-file=.env`.
///
/// Both values are public: the publishable key only identifies the project,
/// and row-level security protects the data. With either one missing, the
/// build has no sync and the app works fully offline.
library;

class SyncConfig {
  const SyncConfig({required this.url, required this.publishableKey});

  static const fromEnvironment = SyncConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String url;
  final String publishableKey;

  bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
