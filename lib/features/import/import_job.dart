/// Shared types for running an import in the background.
library;

import 'dart:async';

import 'import_data.dart';
import 'import_file.dart';

/// A picked file, with its path when it's on local disk.
class PickedImportFile {
  const PickedImportFile(this.file, {this.path});
  final ImportFile file;
  final String? path;
}

/// A running import that the user can cancel.
class ImportJob {
  ImportJob(this.result, this._cancel);
  final Future<ImportedData> result;
  final void Function() _cancel;

  void cancel() => _cancel();
}

/// Thrown into [ImportJob.result] when the user cancels.
class ImportCancelled implements Exception {
  const ImportCancelled();
}

/// Cancels an import that runs on the main isolate: the runner calls
/// [check] between chunks, which yields to the event loop (so the page can
/// draw) and throws once [cancel] was called.
class CancelFlag {
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<void> check() async {
    await Future<void>.delayed(Duration.zero);
    if (_cancelled) throw const ImportCancelled();
  }
}
