/// Picks the import platform layer: an isolate on Android and iOS, the main
/// thread with pauses on the web.
library;

export 'import_job.dart';
export 'import_platform_io.dart' if (dart.library.js_interop) 'import_platform_web.dart'
    show openPickedFile, inspectPicked, startImport;
