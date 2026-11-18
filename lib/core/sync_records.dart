/// The units that sync stores: one record per day log, the profile, each
/// feature key, and each month of period days.
///
/// This file has no sync logic. It lets [AppStore] report changes and accept
/// downloaded records without depending on the sync engine.
library;

import 'dart:async';

import 'dates.dart';

/// What a record holds. The names are stored on the server.
enum SyncKind { day, profile, feature, periods }

/// Identifies one synced record: a kind and a plaintext key, such as
/// `day` / `2026-11-18`, `periods` / `2026-11`, or `feature` / `journal`.
class SyncRef {
  const SyncRef(this.kind, this.key);

  SyncRef.day(String dayKey) : this(SyncKind.day, dayKey);

  SyncRef.feature(String featureKey) : this(SyncKind.feature, featureKey);

  /// The month record (`yyyy-MM`) that holds the period day [d].
  SyncRef.periodsOf(DateTime d) : this(SyncKind.periods, dayKey(d).substring(0, 7));

  static const profile = SyncRef(SyncKind.profile, 'profile');

  final SyncKind kind;
  final String key;

  /// Profile fields that stay on this device: the app-lock PIN protects one
  /// device, so it isn't copied to others.
  static const localProfileFields = {'pin'};

  /// Feature keys that stay on this device: the AI settings (they can hold
  /// the user's own OpenRouter key and a per-device consent) and the record
  /// of notifications already shown here.
  static const localFeatures = {'assistant_ai', 'notifications_log'};

  static bool syncsFeature(String key) => !localFeatures.contains(key);

  /// A stable string form, `kind:key`, used as a map key.
  String get id => '${kind.name}:$key';

  static SyncRef parse(String id) {
    final i = id.indexOf(':');
    return SyncRef(SyncKind.values.byName(id.substring(0, i)), id.substring(i + 1));
  }

  @override
  bool operator ==(Object other) => other is SyncRef && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);

  @override
  String toString() => id;
}

/// A record that sync downloaded. A null [value] means it was deleted.
class RemoteChange {
  const RemoteChange(this.ref, this.value);
  final SyncRef ref;
  final Object? value;
}

/// What the sync engine hears from the store while sync is on.
abstract interface class SyncHooks {
  /// Records changed on this device. Null means any record could have changed.
  void localChanged(Iterable<SyncRef>? refs);

  /// The user erased all data on this device. Sync turns itself off here
  /// first, so the erase doesn't spread to other devices.
  FutureOr<void> localReset();
}
