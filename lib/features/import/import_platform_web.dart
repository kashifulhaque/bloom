/// File access and background work for imports on the web.
///
/// The picked file stays a browser `Blob`: Bloom reads only the slices it
/// needs, and inflates an Apple Health export with the browser's native
/// `DecompressionStream`. Parsing runs on the main thread in small steps,
/// with a pause between chunks so the page keeps drawing.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

import 'import_file.dart';
import 'import_job.dart';
import 'import_runner.dart';

/// A browser `Blob`, read in slices.
class BlobImportFile extends ImportFile {
  BlobImportFile(this.name, this.blob);

  @override
  final String name;
  final web.Blob blob;

  @override
  int get length => blob.size;

  @override
  Future<Uint8List> read(int start, int end) async {
    final buffer = await blob.slice(start, end).arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Stream<List<int>> openRead([int start = 0, int? end]) async* {
    final stop = end ?? length;
    // Larger slices than the default: each one is a round trip to the
    // browser.
    const step = 1024 * 1024;
    for (var pos = start; pos < stop; pos += step) {
      yield await read(pos, pos + step < stop ? pos + step : stop);
    }
  }
}

Future<PickedImportFile> openPickedFile(PlatformFile picked) async {
  final uri = picked.uri.toString();
  if (uri.startsWith('blob:') || uri.startsWith('data:')) {
    final response = await web.window.fetch(uri.toJS).toDart;
    final blob = await response.blob().toDart;
    return PickedImportFile(BlobImportFile(picked.name, blob));
  }
  return PickedImportFile(BytesImportFile(picked.name, await picked.readAsBytes()));
}

Future<FileInspection> inspectPicked(PickedImportFile picked) => inspectImportFile(picked.file);

ImportJob startImport(PickedImportFile picked, FileInspection inspection, ImportRequest request, ImportProgress onProgress) {
  final cancel = CancelFlag();
  return ImportJob(
    runImport(picked.file, inspection, request, onProgress: onProgress, breathe: cancel.check),
    cancel.cancel,
  );
}
