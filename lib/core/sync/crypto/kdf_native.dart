import 'dart:isolate';
import 'dart:typed_data';

import 'kdf.dart';

/// Runs Argon2id in a background isolate so the UI keeps drawing.
Future<Uint8List> argon2id(Uint8List password, Uint8List salt, KdfParams params) =>
    Isolate.run(() => argon2idDart(password, salt, params));
