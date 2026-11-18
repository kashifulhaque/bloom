/// A small ZIP reader that lists entries and streams one of them.
///
/// It reads the central directory from the end of the file (with ZIP64
/// support, since Apple Health exports can pass 4 GB uncompressed) and then
/// streams only the entry it needs. Encrypted entries are left to
/// `package:archive`, which needs the whole archive in memory; Bloom only
/// meets those in small Clue and Flo exports.
library;

import 'dart:typed_data';

import 'import_file.dart';

class ZipEntry {
  const ZipEntry({
    required this.name,
    required this.method,
    required this.flags,
    required this.compressedSize,
    required this.size,
    required this.localHeaderOffset,
  });

  final String name;

  /// 0 is stored, 8 is DEFLATE, and 99 is WinZip AES.
  final int method;
  final int flags;
  final int compressedSize;
  final int size;
  final int localHeaderOffset;

  bool get encrypted => flags & 1 != 0 || method == 99;
  bool get isDirectory => name.endsWith('/');

  /// The file name without folders, in lower case.
  String get baseName {
    final i = name.lastIndexOf('/');
    return (i < 0 ? name : name.substring(i + 1)).toLowerCase();
  }
}

/// True when [head] starts like a ZIP archive.
bool looksLikeZip(Uint8List head) =>
    head.length >= 4 && head[0] == 0x50 && head[1] == 0x4b && (head[2] == 3 || head[2] == 5) && (head[3] == 4 || head[3] == 6);

int _u16(ByteData b, int o) => b.getUint16(o, Endian.little);
int _u32(ByteData b, int o) => b.getUint32(o, Endian.little);

// Two 32-bit reads, because dart2js can't read 64-bit integers.
int _u64(ByteData b, int o) => _u32(b, o) + _u32(b, o + 4) * 0x100000000;

/// Lists the entries of the ZIP archive [file]. Throws [FormatException]
/// when it isn't a readable archive.
Future<List<ZipEntry>> readZipDirectory(ImportFile file) async {
  final len = file.length;
  if (len < 22) throw const FormatException('The ZIP file is too short.');
  final tailStart = len > 65557 ? len - 65557 : 0;
  final tail = await file.read(tailStart, len);
  final tb = ByteData.sublistView(tail);
  var eocd = -1;
  for (var i = tail.length - 22; i >= 0; i--) {
    if (_u32(tb, i) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw const FormatException('The ZIP file is incomplete. Try downloading it again.');

  var count = _u16(tb, eocd + 10);
  var cdSize = _u32(tb, eocd + 12);
  var cdOffset = _u32(tb, eocd + 16);
  if (count == 0xffff || cdSize == 0xffffffff || cdOffset == 0xffffffff) {
    final loc = eocd - 20;
    if (loc < 0 || _u32(tb, loc) != 0x07064b50) throw const FormatException('The ZIP64 locator is missing.');
    final z64Offset = _u64(tb, loc + 8);
    final z64 = ByteData.sublistView(await file.read(z64Offset, z64Offset + 56));
    if (_u32(z64, 0) != 0x06064b50) throw const FormatException('The ZIP64 directory is damaged.');
    count = _u64(z64, 32);
    cdSize = _u64(z64, 40);
    cdOffset = _u64(z64, 48);
  }
  if (cdOffset + cdSize > len) throw const FormatException('The ZIP file is incomplete. Try downloading it again.');

  final cd = await file.read(cdOffset, cdOffset + cdSize);
  final b = ByteData.sublistView(cd);
  final entries = <ZipEntry>[];
  var p = 0;
  for (var n = 0; n < count && p + 46 <= cd.length; n++) {
    if (_u32(b, p) != 0x02014b50) throw const FormatException('The ZIP directory is damaged.');
    final flags = _u16(b, p + 8);
    final method = _u16(b, p + 10);
    var compressed = _u32(b, p + 20);
    var size = _u32(b, p + 24);
    final nameLen = _u16(b, p + 28);
    final extraLen = _u16(b, p + 30);
    final commentLen = _u16(b, p + 32);
    var offset = _u32(b, p + 42);
    final nameBytes = Uint8List.sublistView(cd, p + 46, p + 46 + nameLen);
    // Bit 11 marks UTF-8 names. Older tools use code page 437, which matches
    // UTF-8 for the ASCII names these exports use.
    final name = String.fromCharCodes(nameBytes);
    var e = p + 46 + nameLen;
    final extraEnd = e + extraLen;
    while (e + 4 <= extraEnd) {
      final id = _u16(b, e);
      final size2 = _u16(b, e + 2);
      if (id == 0x0001) {
        var q = e + 4;
        if (size == 0xffffffff) {
          size = _u64(b, q);
          q += 8;
        }
        if (compressed == 0xffffffff) {
          compressed = _u64(b, q);
          q += 8;
        }
        if (offset == 0xffffffff) offset = _u64(b, q);
      }
      e += 4 + size2;
    }
    entries.add(ZipEntry(
      name: name,
      method: method,
      flags: flags,
      compressedSize: compressed,
      size: size,
      localHeaderOffset: offset,
    ));
    p = extraEnd + commentLen;
  }
  return entries;
}

/// Streams the uncompressed bytes of [entry]. Calls [onRead] with the number
/// of compressed bytes read so far, for progress.
Stream<List<int>> openZipEntry(ImportFile file, ZipEntry entry, {void Function(int read)? onRead}) async* {
  if (entry.encrypted) throw const FormatException('This entry is encrypted.');
  final header = ByteData.sublistView(await file.read(entry.localHeaderOffset, entry.localHeaderOffset + 30));
  if (header.lengthInBytes < 30 || _u32(header, 0) != 0x04034b50) {
    throw const FormatException('The ZIP file is damaged.');
  }
  final start = entry.localHeaderOffset + 30 + _u16(header, 26) + _u16(header, 28);
  final end = start + entry.compressedSize;
  if (end > file.length) throw const FormatException('The ZIP file is incomplete. Try downloading it again.');
  var read = 0;
  final raw = file.openRead(start, end).map((chunk) {
    read += chunk.length;
    onRead?.call(read);
    return chunk;
  });
  switch (entry.method) {
    case 0:
      yield* raw;
    case 8:
      yield* inflateRaw(raw);
    default:
      throw FormatException('This ZIP file uses a compression method Bloom can\'t read (${entry.method}).');
  }
}
