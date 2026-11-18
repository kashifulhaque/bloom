/// File access and background work for imports on Android and iOS.
///
/// Parsing runs in its own isolate, so even a multi-gigabyte Apple Health
/// export can't freeze the UI. The isolate opens the file by path and sends
/// back only progress and the mapped result.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'import_data.dart';
import 'import_file.dart';
import 'import_job.dart';
import 'import_runner.dart';

/// A file on disk, read with random access.
class IoImportFile extends ImportFile {
  IoImportFile(this.path) : name = path.split(Platform.pathSeparator).last, length = File(path).lengthSync();

  final String path;
  @override
  final String name;
  @override
  final int length;

  @override
  Future<Uint8List> read(int start, int end) async {
    final raf = await File(path).open();
    try {
      await raf.setPosition(start);
      return await raf.read(end - start);
    } finally {
      await raf.close();
    }
  }

  @override
  Stream<List<int>> openRead([int start = 0, int? end]) => File(path).openRead(start, end ?? length);
}

/// Turns a picked file into an [ImportFile]: by path when the picker gave
/// one, otherwise in memory.
Future<PickedImportFile> openPickedFile(PlatformFile picked) async {
  final path = picked.path;
  if (path != null) return PickedImportFile(IoImportFile(path), path: path);
  return PickedImportFile(BytesImportFile(picked.name, await picked.readAsBytes()));
}

Future<FileInspection> inspectPicked(PickedImportFile picked) {
  final path = picked.path;
  if (path == null) return inspectImportFile(picked.file);
  return Isolate.run(() => inspectImportFile(IoImportFile(path)));
}

ImportJob startImport(PickedImportFile picked, FileInspection inspection, ImportRequest request, ImportProgress onProgress) {
  final path = picked.path;
  if (path == null) {
    final cancel = CancelFlag();
    return ImportJob(
      runImport(picked.file, inspection, request, onProgress: onProgress, breathe: cancel.check),
      cancel.cancel,
    );
  }

  final done = Completer<ImportedData>();
  final port = ReceivePort();
  Isolate? isolate;
  void finish() {
    port.close();
    isolate?.kill(priority: Isolate.immediate);
  }

  port.listen((message) {
    if (message is double) {
      onProgress(message);
    } else if (message is ImportedData) {
      done.complete(message);
      finish();
    } else if (message is List && message.length == 3 && message[0] == 'error') {
      done.completeError(ImportException('${message[2]}', wrongPassword: message[1] == true));
      finish();
    } else if (message is List && message.isNotEmpty) {
      // An uncaught error in the isolate: [error, stack trace].
      done.completeError(ImportException('Bloom couldn\'t read this file. ${message[0]}'));
      finish();
    }
  });
  Isolate.spawn(_importEntry, (port.sendPort, path, inspection, request), errorsAreFatal: true, onError: port.sendPort)
      .then((i) {
    isolate = i;
    if (done.isCompleted) finish();
  }, onError: (Object e) {
    if (!done.isCompleted) done.completeError(ImportException('Bloom couldn\'t start reading the file: $e'));
    port.close();
  });
  return ImportJob(done.future, () {
    if (!done.isCompleted) done.completeError(const ImportCancelled());
    finish();
  });
}

Future<void> _importEntry((SendPort, String, FileInspection, ImportRequest) args) async {
  final (port, path, inspection, request) = args;
  var last = -1.0;
  try {
    final data = await runImport(IoImportFile(path), inspection, request, onProgress: (f) {
      // About 200 updates are plenty for a progress bar.
      if (f - last >= 0.005 || f >= 1) {
        last = f;
        port.send(f);
      }
    });
    Isolate.exit(port, data);
  } on ImportException catch (e) {
    port.send(['error', e.wrongPassword, e.message]);
  } catch (e) {
    port.send(['error', false, 'Bloom couldn\'t read this file. $e']);
  }
}
