/// Raw DEFLATE decoding with `dart:io`, for Android, iOS, and tests.
library;

import 'dart:io';

Stream<List<int>> inflateRaw(Stream<List<int>> input) => ZLibDecoder(raw: true).bind(input);
