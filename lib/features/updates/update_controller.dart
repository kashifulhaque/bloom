/// Checks Bloom's own server for a newer build and decides when to mention
/// it.
///
/// A check is one GET of the static release manifest,
/// `/downloads/manifest.json`, with no identifiers. It runs after startup
/// and when the app resumes, at most once per [UpdatePolicy.interval], and
/// never blocks the UI or shows an error. The result and the user's choices
/// are kept on this device in the `app_updates` feature, which doesn't sync.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/store.dart';
import '../downloads/download_manifest.dart';
import 'app_version.dart';
import 'page_reload_stub.dart' if (dart.library.js_interop) 'page_reload_web.dart' as page;

/// The site that serves the manifest to the Android and iPhone apps. The web
/// app uses its own origin instead.
const String kSiteUrl = String.fromEnvironment('BLOOM_SITE_URL', defaultValue: 'https://bloom.ifkash.dev');

/// The feature key for update state. It stays on this device.
const String kUpdatesFeature = 'app_updates';

/// Where Bloom runs, which decides how it can update.
enum UpdatePlatform {
  /// A signed APK: a newer one installs over it.
  android,

  /// An unsigned IPA that the user re-signed: it can't update itself.
  ios,

  /// The web app: a reload loads the newest deployment.
  web,

  /// Desktop and other builds, which aren't distributed. No checks.
  other;

  /// The platform this build runs on.
  static UpdatePlatform get current {
    if (kIsWeb) return UpdatePlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => UpdatePlatform.android,
      TargetPlatform.iOS => UpdatePlatform.ios,
      _ => UpdatePlatform.other,
    };
  }
}

/// How often a platform checks, and how long "Not now" lasts.
class UpdatePolicy {
  const UpdatePolicy({required this.interval, required this.snooze});

  /// The least time between automatic checks.
  final Duration interval;

  /// How long "Not now" hides one version.
  final Duration snooze;

  /// The wait after a failed check before an automatic retry.
  static const retryAfterFailure = Duration(hours: 1);

  /// How long the note stays hidden after the user taps Download update or
  /// Reload. If the update took, the note is gone for good; if not, it
  /// comes back after this.
  static const afterAction = Duration(hours: 12);

  /// The policy for [platform], or null when it doesn't check.
  static UpdatePolicy? of(UpdatePlatform platform) => switch (platform) {
        UpdatePlatform.android => const UpdatePolicy(interval: Duration(days: 1), snooze: Duration(days: 7)),
        // Rarer and quieter: updating means re-signing an IPA.
        UpdatePlatform.ios => const UpdatePolicy(interval: Duration(days: 7), snooze: Duration(days: 30)),
        // A tab can stay open for days; a reload is cheap.
        UpdatePlatform.web => const UpdatePolicy(interval: Duration(hours: 6), snooze: Duration(days: 1)),
        UpdatePlatform.other => null,
      };
}

/// The outcome of a check.
enum UpdateCheckResult {
  /// The running build is the newest.
  upToDate,

  /// A newer build is on the server.
  available,

  /// The manifest was missing, malformed, or unreachable.
  failed,

  /// This build doesn't check, for example on desktop.
  skipped,
}

/// Opens [url] outside the app. Returns false when it couldn't.
typedef UrlOpener = Future<bool> Function(Uri url);

Future<bool> _openExternally(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Checks for updates and holds what the update note shows.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.store,
    required this.platform,
    required this.running,
    required this.site,
    required this._load,
    DateTime Function()? clock,
    UrlOpener? openUrl,
    VoidCallback? reload,
  })  : _now = clock ?? DateTime.now,
        _openUrl = openUrl ?? _openExternally,
        _reload = reload ?? page.reloadPage;

  /// The controller for the running app.
  factory UpdateController.forApp(AppStore store) {
    final site = kIsWeb ? Uri.base.resolve('/') : Uri.parse(kSiteUrl);
    return UpdateController(
      store: store,
      platform: UpdatePlatform.current,
      running: AppVersion.running,
      site: site,
      load: () => fetchDownloadManifest(base: site),
    );
  }

  final AppStore store;
  final UpdatePlatform platform;

  /// The running build, or null when it's unknown.
  final AppVersion? running;

  /// The site that serves `/downloads/`, with a trailing slash.
  final Uri site;

  final ManifestLoader _load;
  final DateTime Function() _now;
  final UrlOpener _openUrl;
  final VoidCallback _reload;

  Future<UpdateCheckResult>? _inFlight;
  DateTime? _failedAt;
  UpdateCheckResult? _lastResult;

  UpdatePolicy? get policy => UpdatePolicy.of(platform);

  /// Whether this build checks for updates at all.
  bool get supported => policy != null && running != null;

  /// Whether a check is running.
  bool get checking => _inFlight != null;

  /// The result of the last check in this session, or null before one.
  UpdateCheckResult? get lastResult => _lastResult;

  // ------------------------------------------------------------------ state

  Map<String, dynamic> get _state {
    final raw = store.feature<Object>(kUpdatesFeature);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  void _write(void Function(Map<String, dynamic> s) change) {
    final s = _state;
    change(s);
    store.setFeature(kUpdatesFeature, s);
    notifyListeners();
  }

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

  /// Whether automatic checks are on. They're on by default.
  bool get enabled => _state['enabled'] != false;

  set enabled(bool on) => _write((s) => s['enabled'] = on);

  /// When the last successful check finished.
  DateTime? get checkedAt => _date(_state['checkedAt']);

  Map<String, dynamic> get _latest {
    final l = _state['latest'];
    return l is Map ? Map<String, dynamic>.from(l) : const {};
  }

  /// The newest version on the server, as of the last successful check.
  AppVersion? get latest => AppVersion.tryParse(_latest['version'] as String?);

  /// The release notes for [latest], when the manifest had some.
  String? get notes => _latest['notes'] is String ? _latest['notes'] as String : null;

  /// Whether [latest] is newer than the running build.
  bool get updateAvailable {
    final l = latest, r = running;
    return supported && l != null && r != null && l.isNewerThan(r);
  }

  /// When "Not now" (or an update action) stops hiding [version], or null
  /// when it isn't hidden.
  DateTime? _hiddenUntil(AppVersion version) {
    final s = _state['snoozed'];
    if (s is! Map || s['version'] != version.toString()) return null;
    return _date(s['until']);
  }

  /// The newer version that the update note should mention now, or null.
  AppVersion? get pending {
    if (!enabled || !updateAvailable) return null;
    final l = latest!;
    final until = _hiddenUntil(l);
    if (until != null && _now().isBefore(until)) return null;
    return l;
  }

  // ----------------------------------------------------------------- checks

  /// Whether an automatic check is due.
  bool get due {
    final p = policy;
    if (p == null) return false;
    final now = _now();
    final failed = _failedAt;
    if (failed != null && now.difference(failed) < UpdatePolicy.retryAfterFailure) return false;
    final last = checkedAt;
    // A check time in the future means the clock moved back: check again.
    return last == null || last.isAfter(now) || now.difference(last) >= p.interval;
  }

  /// Checks when automatic checks are on and one is due. Never throws.
  Future<void> maybeCheck() async {
    if (!supported || !enabled || checking || !due) return;
    try {
      await check();
    } catch (_) {
      // A check must never surface an error.
    }
  }

  /// Fetches the manifest now. Concurrent calls share one request.
  Future<UpdateCheckResult> check() {
    if (!supported) return Future.value(UpdateCheckResult.skipped);
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final run = _run();
    _inFlight = run;
    notifyListeners();
    return run.whenComplete(() {
      _inFlight = null;
      notifyListeners();
    });
  }

  Future<UpdateCheckResult> _run() async {
    DownloadManifest? m;
    try {
      m = await _load();
    } catch (_) {
      m = null;
    }
    final version = AppVersion.tryParse(m?.version);
    if (m == null || version == null) {
      _failedAt = _now();
      return _lastResult = UpdateCheckResult.failed;
    }
    _failedAt = null;
    _write((s) {
      s['checkedAt'] = _now().toUtc().toIso8601String();
      s['latest'] = {
        'version': version.toString(),
        if (m!.notes != null) 'notes': m.notes,
        if (m.apk != null) 'apk': m.apk!.path,
      };
    });
    return _lastResult = version.isNewerThan(running!) ? UpdateCheckResult.available : UpdateCheckResult.upToDate;
  }

  // ---------------------------------------------------------------- actions

  void _hide(AppVersion version, Duration d) => _write((s) => s['snoozed'] = {
        'version': version.toString(),
        'until': _now().add(d).toUtc().toIso8601String(),
      });

  /// "Not now": hides the pending version for [UpdatePolicy.snooze]. A
  /// newer version shows again right away.
  void snooze() {
    final v = latest, p = policy;
    if (v != null && p != null) _hide(v, p.snooze);
  }

  /// The APK on the site.
  Uri get apkUrl => site.resolve(_latest['apk'] as String? ?? '/downloads/bloom.apk');

  /// The web app.
  Uri get webAppUrl => site;

  /// The web app's "Get the app" page.
  Uri get getAppUrl => site.replace(fragment: '/get-app');

  /// Android: opens the APK in the browser, which downloads it. Android then
  /// installs it over this app, because both are signed with the same key.
  Future<bool> downloadUpdate() async {
    final v = latest;
    final ok = await _openUrl(apkUrl);
    if (ok && v != null) _hide(v, UpdatePolicy.afterAction);
    return ok;
  }

  /// Web: reloads the tab to load the newest deployment.
  void reloadNow() {
    final v = latest;
    // If the reload still serves the old build, don't ask again at once.
    if (v != null) _hide(v, UpdatePolicy.afterAction);
    _reload();
  }

  /// Opens [url] outside the app, such as the web app from the iPhone app.
  Future<bool> open(Uri url) => _openUrl(url);
}

/// The app's [UpdateController], or null when none is provided (for
/// example, in widget tests of other screens).
UpdateController? watchUpdates(BuildContext context) {
  try {
    return context.watch<UpdateController>();
  } on ProviderNotFoundException {
    return null;
  }
}
