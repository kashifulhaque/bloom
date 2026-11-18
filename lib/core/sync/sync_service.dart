/// What the sync engine needs from a server: email sign-in, the wrapped key,
/// and encrypted rows. [SupabaseSyncService] talks to Supabase; tests use a
/// fake.
library;

import 'sync_models.dart';

/// A server error the user can act on, such as a wrong code.
class SyncServiceException implements Exception {
  const SyncServiceException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

abstract interface class SyncService {
  /// The signed-in user's id, or null when signed out.
  String? get userId;

  /// The signed-in user's email address.
  String? get email;

  /// Emails a 6-digit sign-in code. Creates the account on first use.
  Future<void> sendCode(String email);

  /// Signs in with the emailed code.
  Future<void> verifyCode(String email, String code);

  /// Signs out on this device.
  Future<void> signOut();

  /// The user's wrapped data key, or null when sync was never set up.
  Future<WrappedKey?> fetchKey();

  /// Stores the wrapped data key. Returns false, without changing anything,
  /// when the account already has one (another device got there first).
  Future<bool> insertKey(WrappedKey key);

  /// Inserts or updates rows. Returns the rows the server accepted. A row is
  /// left out when the server already has the same or a newer version.
  Future<List<RowVersion>> upsert(List<RemoteRow> rows);

  /// Rows after [after] in `(updated_at, record_id)` order, oldest first. A
  /// null [after] starts at the beginning.
  Future<List<RemoteRow>> pull({PullCursor? after, required int limit});

  /// The current server copy of specific rows (`kind:recordId` ids).
  Future<List<RemoteRow>> fetch(List<RemoteRow> rows);

  /// Deletes the account and all its rows on the server, then signs out.
  Future<void> deleteAccount();
}
