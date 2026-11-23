import 'dart:convert';

/// Hash FNV-1a 64-bit (dua lintasan 32-bit) yang stabil antar-run.
///
/// `String.hashCode` di Dart tidak dijamin stabil antar proses, sehingga tidak
/// boleh dipakai untuk nama berkas cache atau ID yang disimpan permanen.
String stableHash(String value) {
  var h1 = 0x811C9DC5;
  var h2 = 0x9E3779B9;
  for (final byte in utf8.encode(value)) {
    h1 = ((h1 ^ byte) * 0x01000193) & 0xFFFFFFFF;
    h2 = ((h2 ^ byte) * 0x85EBCA6B) & 0xFFFFFFFF;
  }
  return h1.toRadixString(16).padLeft(8, '0') +
      h2.toRadixString(16).padLeft(8, '0');
}
