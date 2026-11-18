// Crypto for sync. Runs on the Dart VM and in Chrome:
//
//   flutter test test/sync_crypto_test.dart
//   flutter test --platform chrome test/sync_crypto_test.dart
//
// The vectors come from native libsodium 1.0.22 (Argon2id, XChaCha20-Poly1305)
// and Python's hmac and hashlib (HKDF and HMAC-SHA256), so passing on both
// platforms shows they produce and accept the same bytes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:bloom/core/sync/crypto/kdf.dart';
import 'package:bloom/core/sync/crypto/recovery_phrase.dart';
import 'package:bloom/core/sync/crypto/sync_crypto.dart';
import 'package:bloom/core/sync/key_store.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List hex(String s) => Uint8List.fromList([for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)]);
String toHex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
Uint8List seq(int n, [int start = 0]) => Uint8List.fromList(List.generate(n, (i) => start + i));

/// Made by libsodium's crypto_aead_xchacha20poly1305_ietf_encrypt with the
/// record subkey of data key 00..1f, nonce 07 x 24, and Bloom's record AAD.
const libsodiumRecordBox =
    '010707070707070707070707070707070707070707070707071df12172a12bc4cdf328f74199a691ebfb5c827d99750c190c836e37fb271df1'
    '62b3139dba29f5ea5b82a600119642e58a907e77edff10063610805aaef741a581f604d14304db180380546405e64283317482bfe2e6b7d2e5'
    '52c36e3f23dfed217176dacc52f987cf53';

void main() {
  group('Recovery phrase', () {
    test('matches the BIP-39 reference vectors', () {
      expect(RecoveryPhrase.fromEntropy(Uint8List(16)).toString(),
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about');
      expect(RecoveryPhrase.fromEntropy(Uint8List.fromList(List.filled(16, 0x7f))).toString(),
          'legal winner thank year wave sausage worth useful legal winner thank yellow');
      expect(RecoveryPhrase.fromEntropy(Uint8List.fromList(List.filled(16, 0xff))).toString(),
          'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong');
    });

    test('round-trips and ignores case and spacing', () {
      final p = RecoveryPhrase.generate();
      expect(p.words, hasLength(12));
      final typed = '  ${p.words.map((w) => w.toUpperCase()).join('\n ')}  ';
      expect(RecoveryPhrase.parse(typed).entropy, p.entropy);
    });

    test('rejects wrong length, unknown words, and a bad checksum', () {
      expect(() => RecoveryPhrase.parse('abandon ' * 11), throwsA(isA<InvalidPhraseException>()));
      expect(() => RecoveryPhrase.parse('${'abandon ' * 11}bloomz'), throwsA(isA<InvalidPhraseException>()));
      // "abandon" x 12 has the wrong checksum.
      expect(() => RecoveryPhrase.parse('abandon ' * 12), throwsA(isA<InvalidPhraseException>()));
    });
  });

  group('Argon2id', () {
    test('matches libsodium (8 MiB, 1 pass)', () async {
      final out = await argon2id(seq(16), seq(16, 0xa0), const KdfParams(memKiB: 8192, iterations: 1));
      expect(toHex(out), 'df5384c8197f0117c0449c4ce1ec80c5a3e0d02f7652490f4bb93631f15e485b');
    });

    test('matches libsodium with the production parameters (64 MiB, 2 passes)', () async {
      final sw = Stopwatch()..start();
      final out = await argon2id(seq(16), seq(16, 0xa0), KdfParams.current);
      expect(toHex(out), '6e64baec07f632778ca7624eee804699f4fa2b033c9522ff40f9a3584d9ff340');
      // ignore: avoid_print
      print('Argon2id ${KdfParams.current.memKiB} KiB x ${KdfParams.current.iterations}: ${sw.elapsedMilliseconds} ms');
    }, testOn: 'vm');

    test('rejects parameters outside the supported range', () {
      expect(() => argon2id(seq(16), seq(16), const KdfParams(memKiB: 1024, iterations: 1)), throwsUnsupportedError);
    });
  });

  group('Data key', () {
    test('wraps and unwraps; a different phrase fails', () async {
      const params = KdfParams(memKiB: 8192, iterations: 1);
      final phrase = RecoveryPhrase.generate();
      final salt = SyncCrypto.newSalt();
      final dataKey = SyncCrypto.newDataKey();
      final kek = await SyncCrypto.deriveKek(phrase.entropy, salt, params);
      final wrapped = await SyncCrypto.wrapDataKey(dataKey, kek);
      expect(wrapped, hasLength(73));
      expect(await SyncCrypto.unwrapDataKey(wrapped, kek), dataKey);

      final other = await SyncCrypto.deriveKek(RecoveryPhrase.generate().entropy, salt, params);
      await expectLater(SyncCrypto.unwrapDataKey(wrapped, other), throwsA(isA<WrongPhraseException>()));
    });
  });

  group('Records', () {
    late SyncCrypto crypto;
    setUp(() async => crypto = await SyncCrypto.fromDataKey(seq(32)));

    test('record ids match HKDF-SHA256 + HMAC-SHA256 from Python', () async {
      expect(await crypto.recordId('day', '2026-11-18'), '3DrJyTqH_oJK8PBhSJbBtAzWgmojsa6GMVm81pAMqMU');
      expect(await crypto.recordId('day', '2026-11-19'), isNot('3DrJyTqH_oJK8PBhSJbBtAzWgmojsa6GMVm81pAMqMU'));
    });

    test('opens a box made by libsodium', () async {
      final plain = await crypto.open(
        kind: 'day',
        recordId: '3DrJyTqH_oJK8PBhSJbBtAzWgmojsa6GMVm81pAMqMU',
        version: 42,
        deleted: false,
        box: hex(libsodiumRecordBox),
      );
      expect(jsonDecode(utf8.decode(plain)), {
        'k': '2026-11-18',
        'v': {'date': '2026-11-18', 'metrics': {}, 'selections': {'flow': ['medium']}},
      });
    });

    test('round-trips, and any change to the box or its row fails', () async {
      final box = await crypto.seal(kind: 'day', recordId: 'abc', version: 7, deleted: false, plaintext: utf8.encode('hi'));
      expect(box.length, SyncCrypto.overhead + 2);
      expect(utf8.decode(await crypto.open(kind: 'day', recordId: 'abc', version: 7, deleted: false, box: box)), 'hi');

      Future<void> fails(Future<Object?> f) => expectLater(f, throwsA(isA<SyncCryptoException>()));
      await fails(crypto.open(kind: 'day', recordId: 'abc', version: 8, deleted: false, box: box));
      await fails(crypto.open(kind: 'day', recordId: 'abd', version: 7, deleted: false, box: box));
      await fails(crypto.open(kind: 'feature', recordId: 'abc', version: 7, deleted: false, box: box));
      await fails(crypto.open(kind: 'day', recordId: 'abc', version: 7, deleted: true, box: box));
      final flipped = Uint8List.fromList(box)..[30] ^= 1;
      await fails(crypto.open(kind: 'day', recordId: 'abc', version: 7, deleted: false, box: flipped));
      final other = await SyncCrypto.fromDataKey(seq(32, 1));
      await fails(other.open(kind: 'day', recordId: 'abc', version: 7, deleted: false, box: box));
    });

    test('each box uses a fresh nonce', () async {
      final a = await crypto.seal(kind: 'day', recordId: 'x', version: 1, deleted: false, plaintext: [1]);
      final b = await crypto.seal(kind: 'day', recordId: 'x', version: 1, deleted: false, plaintext: [1]);
      expect(toHex(a), isNot(toHex(b)));
    });
  });

  test('the web key store keeps the data key in IndexedDB behind WebCrypto', () async {
    final store = platformKeyStore();
    await store.clear();
    expect(await store.read(), isNull);
    final key = seq(32, 9);
    await store.write(StoredKey('user-1', key));
    final back = await store.read();
    expect(back!.userId, 'user-1');
    expect(back.dataKey, key);
    await store.clear();
    expect(await store.read(), isNull);
  }, testOn: 'browser');
}
