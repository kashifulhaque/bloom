/// Random-access reading of a picked file, so a parser can read a ZIP's
/// directory at the end of the file and then stream one entry, without
/// loading a large export into memory.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'inflate_io.dart' if (dart.library.js_interop) 'inflate_web.dart' as platform;

/// A file that can be read in ranges.
abstract class ImportFile {
  String get name;

  /// Size in bytes.
  int get length;

  /// Reads bytes [start] up to [end] (exclusive).
  Future<Uint8List> read(int start, int end);

  /// Streams bytes [start] up to [end] (exclusive, defaults to the end).
  Stream<List<int>> openRead([int start = 0, int? end]) async* {
    final stop = end ?? length;
    for (var pos = start; pos < stop; pos += chunkSize) {
      yield await read(pos, math.min(pos + chunkSize, stop));
    }
  }

  /// Size of the chunks that [openRead] emits by default.
  static const chunkSize = 256 * 1024;
}

/// A file already in memory. Used for tests and for small files.
class BytesImportFile extends ImportFile {
  BytesImportFile(this.name, this.bytes);

  @override
  final String name;
  final Uint8List bytes;

  @override
  int get length => bytes.length;

  @override
  Future<Uint8List> read(int start, int end) async =>
      Uint8List.sublistView(bytes, start.clamp(0, bytes.length), end.clamp(0, bytes.length));
}

/// Inflates a raw DEFLATE stream (ZIP method 8) chunk by chunk. It uses
/// `dart:io` on Android and iOS and the browser's `DecompressionStream` on
/// the web, so memory use stays flat whatever the entry's size.
Stream<List<int>> inflateRaw(Stream<List<int>> input) => platform.inflateRaw(input);
