/// Raw DEFLATE decoding with the browser's `DecompressionStream`, so a large
/// Apple Health export inflates in native code, one chunk at a time.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Stream<List<int>> inflateRaw(Stream<List<int>> input) async* {
  final ds = web.DecompressionStream('deflate-raw');
  final writer = ds.writable.getWriter();
  Object? writeError;

  // Feed the input while the loop below reads, so neither side waits on a
  // full queue.
  unawaited(() async {
    try {
      await for (final chunk in input) {
        await writer.ready.toDart;
        final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        unawaited(writer.write(bytes.toJS).toDart.then((_) {}, onError: (Object e) => writeError ??= e));
      }
      await writer.close().toDart;
    } catch (e) {
      writeError ??= e;
      unawaited(writer.abort().toDart.then((_) {}, onError: (_) {}));
    }
  }());

  final reader = ds.readable.getReader() as web.ReadableStreamDefaultReader;
  while (true) {
    final web.ReadableStreamReadResult result;
    try {
      result = await reader.read().toDart;
    } catch (e) {
      throw FormatException('The compressed data is damaged: ${writeError ?? e}');
    }
    if (result.done) break;
    yield (result.value as JSUint8Array).toDart;
  }
  if (writeError != null) throw FormatException('The compressed data is damaged: $writeError');
}
