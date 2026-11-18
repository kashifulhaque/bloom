/// App versions such as `1.0.0+7`, and the version of the running build.
library;

import 'package:flutter/services.dart' show appBuildName, appBuildNumber;

/// A version name and an optional build number, as in `1.0.0+7`.
///
/// CI sets the build number to the workflow run number, so it grows with
/// every release. Two versions that both have a build number compare by it
/// alone; otherwise they compare by their dotted names.
class AppVersion {
  const AppVersion(this.name, [this.build]);

  /// The dotted version name, such as `1.0.0`.
  final String name;

  /// The build number, such as `7`, or null when there isn't one.
  final int? build;

  static final _pattern = RegExp(r'^(\d{1,6}(?:\.\d{1,6}){0,3})(?:\+(\d{1,9}))?$');

  /// Parses [text], or returns null when it's missing or malformed.
  static AppVersion? tryParse(String? text) {
    final m = _pattern.firstMatch(text?.trim() ?? '');
    if (m == null) return null;
    final build = m.group(2);
    return AppVersion(m.group(1)!, build == null ? null : int.parse(build));
  }

  /// The running build, from `--build-name` and `--build-number` (or the
  /// pubspec `version`), which Flutter compiles into the app.
  ///
  /// This is a build-time value, not `package_info_plus`: on the web, that
  /// package reads `version.json` from the server, which describes the
  /// newest deployment rather than the code running in this tab.
  static final AppVersion? running = fromBuild(appBuildName, appBuildNumber);

  /// The version that [name] and [build] describe, or null when neither
  /// is usable.
  static AppVersion? fromBuild(String? name, String? build) {
    final n = name?.trim() ?? '', b = build?.trim() ?? '';
    if (b.isEmpty) return tryParse(n);
    return tryParse('${n.isEmpty ? '0' : n}+$b') ?? tryParse(n);
  }

  /// Whether this version is newer than [other].
  bool isNewerThan(AppVersion other) {
    final a = build, b = other.build;
    if (a != null && b != null) return a > b;
    return _compareNames(name, other.name) > 0;
  }

  static int _compareNames(String a, String b) {
    final x = a.split('.').map(int.parse).toList();
    final y = b.split('.').map(int.parse).toList();
    for (var i = 0; i < x.length || i < y.length; i++) {
      final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
      if (c != 0) return c;
    }
    return 0;
  }

  /// For people: `1.0.0 (build 7)`.
  String get label => build == null ? name : '$name (build $build)';

  @override
  String toString() => build == null ? name : '$name+$build';

  @override
  bool operator ==(Object other) => other is AppVersion && other.name == name && other.build == build;

  @override
  int get hashCode => Object.hash(name, build);
}
