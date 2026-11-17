/// Hashing for the app-lock PIN.
///
/// The PIN is stored as `fnv1a:<salt>:<hash>`, where the hash is 64-bit
/// FNV-1a over the salt and PIN, iterated 2,000 times. This is obfuscation,
/// not encryption: a 4-digit PIN has only 10,000 values, so anyone with the
/// stored data can brute-force it. It only keeps the PIN out of plain sight
/// in backups and local storage. A real key-derivation function needs a
/// crypto package, which this project doesn't include.
library;

import 'dart:convert';
import 'dart:math';

const _prefix = 'fnv1a';
const _rounds = 2000;

// 64-bit FNV-1a constants, split into 32-bit halves so the math stays exact
// on the web, where integers are JavaScript doubles.
const _offsetHi = 0xcbf29ce4;
const _offsetLo = 0x84222325;
const _primeHi = 0x00000100;
const _primeLo = 0x000001b3;

/// Returns the 64-bit FNV-1a hash of [bytes] as 16 hex characters.
String fnv1a64(List<int> bytes) {
  var hi = _offsetHi, lo = _offsetLo;
  for (final b in bytes) {
    lo ^= b & 0xff;
    // (hi:lo) * (primeHi:primeLo) mod 2^64, using 16-bit limbs.
    final r = _mul64(hi, lo, _primeHi, _primeLo);
    hi = r.$1;
    lo = r.$2;
  }
  return hi.toRadixString(16).padLeft(8, '0') + lo.toRadixString(16).padLeft(8, '0');
}

(int, int) _mul64(int aHi, int aLo, int bHi, int bLo) {
  final a0 = aLo & 0xffff, a1 = (aLo >>> 16) & 0xffff, a2 = aHi & 0xffff, a3 = (aHi >>> 16) & 0xffff;
  final b0 = bLo & 0xffff, b1 = (bLo >>> 16) & 0xffff, b2 = bHi & 0xffff, b3 = (bHi >>> 16) & 0xffff;
  var c0 = a0 * b0;
  var c1 = (c0 >>> 16) + a0 * b1;
  var c2 = c1 >>> 16;
  c1 = (c1 & 0xffff) + a1 * b0;
  c2 += c1 >>> 16;
  c2 += a0 * b2;
  var c3 = c2 >>> 16;
  c2 = (c2 & 0xffff) + a1 * b1;
  c3 += c2 >>> 16;
  c2 = (c2 & 0xffff) + a2 * b0;
  c3 += c2 >>> 16;
  c3 += a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0;
  final lo = ((c1 & 0xffff) << 16) | (c0 & 0xffff);
  final hi = ((c3 & 0xffff) << 16) | (c2 & 0xffff);
  return (hi & 0xffffffff, lo & 0xffffffff);
}

String _derive(String salt, String pin) {
  var h = fnv1a64(utf8.encode('$salt:$pin'));
  for (var i = 0; i < _rounds; i++) {
    h = fnv1a64(utf8.encode('$h$salt$pin'));
  }
  return h;
}

/// Hashes [pin] with a fresh random salt. Pass [salt] only in tests.
String hashPin(String pin, {String? salt}) {
  final s = salt ?? _randomSalt();
  return '$_prefix:$s:${_derive(s, pin)}';
}

/// True when [pin] matches [stored]. Also accepts a legacy plain-text PIN.
bool verifyPin(String pin, String? stored) {
  if (stored == null) return false;
  final parts = stored.split(':');
  if (parts.length == 3 && parts[0] == _prefix) {
    return _derive(parts[1], pin) == parts[2];
  }
  return stored == pin;
}

String _randomSalt() {
  final r = Random.secure();
  return List.generate(8, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
