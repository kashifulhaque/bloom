/// Argon2id key derivation for the recovery phrase.
///
/// Native platforms run the `cryptography` package's Dart Argon2id in a
/// background isolate. The web calls libsodium.js (`web/sodium.js`, loaded only
/// when needed) because Argon2id compiled to JavaScript is several times too
/// slow; if libsodium.js can't load, the web falls back to the Dart version.
/// Both are RFC 9106 Argon2id version 1.3 and give the same bytes, which the
/// tests check against vectors from native libsodium.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'kdf_native.dart' if (dart.library.js_interop) 'kdf_web.dart' as platform;

/// Argon2id parameters. They're stored with the salt in `sync_keys`, so a
/// later version can raise them without breaking existing keys.
class KdfParams {
  const KdfParams({required this.memKiB, required this.iterations, this.parallelism = 1, this.alg = argon2id13});

  static const argon2id13 = 'argon2id13';

  /// The parameters for new keys: 64 MiB, 2 passes, 1 lane. These match
  /// libsodium's `crypto_pwhash_*_INTERACTIVE` limits. Measured times are in
  /// docs/SYNC_PLAN.md ("Implementation notes").
  static const current = KdfParams(memKiB: 65536, iterations: 2);

  final int memKiB;
  final int iterations;
  final int parallelism;
  final String alg;

  /// Whether this build can use these parameters. The ranges match the
  /// `sync_keys` check constraints.
  bool get supported =>
      alg == argon2id13 && parallelism == 1 && memKiB >= 8192 && memKiB <= 1048576 && iterations >= 1 && iterations <= 16;
}

/// Derives a 32-byte key from [password] and a 16-byte [salt].
Future<Uint8List> argon2id(Uint8List password, Uint8List salt, KdfParams params) {
  if (!params.supported) throw UnsupportedError('Unsupported key parameters: ${params.alg}');
  return platform.argon2id(password, salt, params);
}

/// The pure Dart Argon2id, on the calling isolate. Used by the platform
/// versions and by tests.
Future<Uint8List> argon2idDart(Uint8List password, Uint8List salt, KdfParams params) async {
  final algorithm = Argon2id(
    parallelism: params.parallelism,
    memory: params.memKiB,
    iterations: params.iterations,
    hashLength: 32,
  );
  final key = await algorithm.deriveKey(secretKey: SecretKeyData(password), nonce: salt);
  return Uint8List.fromList(await key.extractBytes());
}
