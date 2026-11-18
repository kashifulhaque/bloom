/// The 12-word recovery phrase: 128 bits of random entropy encoded with the
/// standard BIP-39 English wordlist and checksum.
///
/// Bloom uses BIP-39 only as an encoding. The phrase decodes back to its 16
/// entropy bytes, and those bytes, not the words, are the Argon2id input, so
/// spacing and letter case never change the derived key. Bloom doesn't use the
/// BIP-39 seed (PBKDF2) step.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';

import 'bip39_english.dart';

class InvalidPhraseException implements Exception {
  const InvalidPhraseException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RecoveryPhrase {
  RecoveryPhrase._(this.entropy, this.words);

  static const wordCount = 12;
  static const entropyBytes = 16;

  /// The 16 random bytes behind the phrase.
  final Uint8List entropy;

  /// The 12 words, lowercase, in order.
  final List<String> words;

  static final _index = {for (var i = 0; i < bip39English.length; i++) bip39English[i]: i};

  /// A new phrase from a cryptographically secure random source.
  factory RecoveryPhrase.generate([Random? random]) {
    final r = random ?? Random.secure();
    return RecoveryPhrase.fromEntropy(Uint8List.fromList(List.generate(entropyBytes, (_) => r.nextInt(256))));
  }

  factory RecoveryPhrase.fromEntropy(Uint8List entropy) {
    if (entropy.length != entropyBytes) throw ArgumentError('Need $entropyBytes bytes of entropy');
    final bits = _bits(entropy) + _checksumBits(entropy);
    final words = [
      for (var i = 0; i < wordCount; i++) bip39English[int.parse(bits.substring(i * 11, i * 11 + 11), radix: 2)],
    ];
    return RecoveryPhrase._(Uint8List.fromList(entropy), List.unmodifiable(words));
  }

  /// Parses a typed phrase. Accepts any spacing, line breaks, and letter case.
  /// Throws [InvalidPhraseException] with a message the user can act on.
  factory RecoveryPhrase.parse(String input) {
    final words = normalize(input);
    if (words.length != wordCount) {
      throw InvalidPhraseException('Enter all $wordCount words. You entered ${words.length}.');
    }
    final unknown = [for (final w in words) if (!_index.containsKey(w)) w];
    if (unknown.isNotEmpty) {
      throw InvalidPhraseException('${unknown.map((w) => '"$w"').join(', ')} '
          '${unknown.length == 1 ? 'isn\'t a word' : 'aren\'t words'} from the recovery list. Check the spelling.');
    }
    final bits = words.map((w) => _index[w]!.toRadixString(2).padLeft(11, '0')).join();
    final entropy = Uint8List(entropyBytes);
    for (var i = 0; i < entropyBytes; i++) {
      entropy[i] = int.parse(bits.substring(i * 8, i * 8 + 8), radix: 2);
    }
    if (bits.substring(128) != _checksumBits(entropy)) {
      throw const InvalidPhraseException('These words don\'t form a valid phrase. Check their order and spelling.');
    }
    return RecoveryPhrase._(entropy, List.unmodifiable(words));
  }

  /// Splits [input] into lowercase words.
  static List<String> normalize(String input) =>
      input.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();

  /// Whether [word] is on the wordlist.
  static bool isWord(String word) => _index.containsKey(word.toLowerCase());

  static String _bits(Uint8List bytes) => bytes.map((b) => b.toRadixString(2).padLeft(8, '0')).join();

  /// The first 4 bits of SHA-256(entropy).
  static String _checksumBits(Uint8List entropy) {
    final hash = const DartSha256().hashSync(entropy).bytes;
    return hash[0].toRadixString(2).padLeft(8, '0').substring(0, 4);
  }

  @override
  String toString() => words.join(' ');
}
