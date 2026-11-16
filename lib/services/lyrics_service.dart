import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LyricsLine {
  final Duration timestamp;
  final String text;

  const LyricsLine({required this.timestamp, required this.text});
}

/// Pengambil lirik dari LRCLIB.
///
/// Parser LRC dan lirik biasa diekstrak sebagai fungsi statis murni agar dapat
/// diuji tanpa akses jaringan.
class LyricsService {
  final Dio _dio;

  LyricsService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ));

  Future<List<LyricsLine>> fetchLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final cleanTitle = title.split('(').first.split('-').first.trim();
      final cleanArtist = artist.split(',').first.split('&').first.trim();

      final response = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: {
          'track_name': cleanTitle,
          'artist_name': cleanArtist,
        },
      );

      if (response.statusCode == 200) {
        final data =
            response.data is String ? json.decode(response.data) : response.data;
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) {
          return parseLrc(synced);
        }

        final plain = data['plainLyrics'] as String?;
        if (plain != null && plain.isNotEmpty) {
          return parsePlain(plain);
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] pengambilan lirik gagal: $e');
    }

    return [];
  }

  /// Mengurai lirik tersinkron (format LRC).
  ///
  /// Contoh baris: `[00:12.34] Teks lirik`.
  static List<LyricsLine> parseLrc(String lrcContent) {
    final List<LyricsLine> lines = [];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3)!;
        final millis = int.parse(millisStr.padRight(3, '0').substring(0, 3));

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        final text = match.group(4)?.trim() ?? '';
        lines.add(LyricsLine(timestamp: duration, text: text));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Mengurai lirik tanpa timestamp; jarak antar baris diperkirakan 4 detik.
  static List<LyricsLine> parsePlain(String plainContent) {
    final List<LyricsLine> lines = [];
    for (final rawLine in plainContent.split('\n')) {
      final text = rawLine.trim();
      if (text.isEmpty) continue;
      lines.add(LyricsLine(
        timestamp: Duration(seconds: lines.length * 4),
        text: text,
      ));
    }
    return lines;
  }
}
