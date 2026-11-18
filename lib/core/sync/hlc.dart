/// A hybrid logical clock (HLC) that produces record versions.
///
/// A version is one integer that orders writes across devices: later edits get
/// larger versions even when device clocks disagree a little, and two devices
/// never produce the same version because the low bits hold a device tag.
///
/// Layout, chosen so every version stays below 2^53 and is exact as a
/// JavaScript number on the web and as JSON:
///
/// ```none
/// version = millisSinceEpoch2025 * 4096 + counter * 64 + node
/// ```
///
/// - `millisSinceEpoch2025`: milliseconds since 2025-01-01 UTC. It fits until
///   about the year 2094.
/// - `counter` (0 to 63): orders events within one millisecond.
/// - `node` (0 to 63): a random tag for this device.
///
/// The math uses `*`, `~/`, and `%`, never bit shifts, because shifts are
/// 32-bit on the web.
library;

import 'dart:math';

class Hlc {
  Hlc({required this.node, this._lastMillis = 0, this._counter = 0, int Function()? now})
      : assert(node >= 0 && node < nodes),
        _now = now ?? _wallMillis;

  /// A clock with a random device tag.
  factory Hlc.random({int Function()? now}) => Hlc(node: Random.secure().nextInt(nodes), now: now);

  /// 2025-01-01T00:00:00Z in milliseconds since the Unix epoch.
  static const epochMillis = 1735689600000;
  static const nodes = 64;
  static const counters = 64;
  static const _perMilli = nodes * counters; // 4096

  /// The largest version this layout can hold (2^53 - 1).
  static const maxVersion = 9007199254740991;

  final int node;
  int _lastMillis;
  int _counter;
  final int Function() _now;

  static int _wallMillis() => DateTime.now().millisecondsSinceEpoch - epochMillis;

  /// A new version, greater than every version this clock has made or seen.
  int next() {
    final wall = _now();
    if (wall > _lastMillis) {
      _lastMillis = wall;
      _counter = 0;
    } else if (++_counter >= counters) {
      // More than 64 events in one millisecond: borrow the next one.
      _lastMillis++;
      _counter = 0;
    }
    return compose(_lastMillis, _counter, node);
  }

  /// Moves the clock past a version from another device, so this device's
  /// next edit sorts after it.
  void observe(int version) {
    final millis = millisOf(version);
    final counter = counterOf(version);
    if (millis > _lastMillis || (millis == _lastMillis && counter > _counter)) {
      _lastMillis = millis;
      _counter = counter;
    }
  }

  static int compose(int millis, int counter, int node) {
    final v = millis * _perMilli + counter * nodes + node;
    if (v <= 0 || v > maxVersion) throw RangeError.range(v, 1, maxVersion, 'version');
    return v;
  }

  static int millisOf(int version) => version ~/ _perMilli;
  static int counterOf(int version) => (version % _perMilli) ~/ nodes;
  static int nodeOf(int version) => version % nodes;

  /// The wall-clock time a version was made, for display.
  static DateTime timeOf(int version) =>
      DateTime.fromMillisecondsSinceEpoch(millisOf(version) + epochMillis, isUtc: true);

  Map<String, Object> toJson() => {'node': node, 'millis': _lastMillis, 'counter': _counter};

  factory Hlc.fromJson(Map<String, dynamic> j, {int Function()? now}) =>
      Hlc(node: j['node'] as int, lastMillis: j['millis'] as int? ?? 0, counter: j['counter'] as int? ?? 0, now: now);
}
