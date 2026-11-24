import 'dart:convert';

class TrackModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final int durationMs;
  final String? youtubeId;
  final String? localPath;

  /// MIME type kontainer audio (mis. `audio/mp4`). Disimpan agar pemutar dan
  /// proses ekspor mengetahui format asli berkas tanpa menebak dari ekstensi.
  final String? mimeType;

  /// Timestamp epoch milidetik saat lagu disukai pengguna.
  /// Dipakai untuk pengurutan koleksi lagu disukai (terbaru di atas).
  final int? likedAt;

  const TrackModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.durationMs,
    this.youtubeId,
    this.localPath,
    this.mimeType,
    this.likedAt,
  });

  bool get isDownloaded => localPath != null && localPath!.isNotEmpty;

  /// Durasi yang benar-benar diketahui. Berkas lokal yang dipindai tidak
  /// memiliki metadata durasi sehingga nilainya 0.
  bool get hasKnownDuration => durationMs > 0;

  String get formattedDuration {
    if (durationMs <= 0) return '--:--';
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedLikedDate {
    if (likedAt == null || likedAt == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(likedAt!);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  TrackModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    int? durationMs,
    String? youtubeId,
    String? localPath,
    String? mimeType,
    int? likedAt,
  }) {
    return TrackModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      durationMs: durationMs ?? this.durationMs,
      youtubeId: youtubeId ?? this.youtubeId,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      likedAt: likedAt ?? this.likedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'artworkUrl': artworkUrl,
      'durationMs': durationMs,
      'youtubeId': youtubeId,
      'localPath': localPath,
      'mimeType': mimeType,
      'likedAt': likedAt,
    };
  }

  factory TrackModel.fromMap(Map<String, dynamic> map) {
    return TrackModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Unknown Title',
      artist: map['artist']?.toString() ?? 'Unknown Artist',
      album: map['album']?.toString() ?? '',
      artworkUrl: map['artworkUrl']?.toString() ?? '',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      youtubeId: map['youtubeId']?.toString(),
      localPath: map['localPath']?.toString(),
      mimeType: map['mimeType']?.toString(),
      likedAt: (map['likedAt'] as num?)?.toInt(),
    );
  }

  factory TrackModel.fromDeezer(Map<String, dynamic> map) {
    final albumMap = map['album'] as Map<String, dynamic>?;
    final artistMap = map['artist'] as Map<String, dynamic>?;

    final cover = albumMap?['cover_xl'] ??
        albumMap?['cover_big'] ??
        albumMap?['cover_medium'] ??
        albumMap?['cover'] ??
        '';

    final durationSec = (map['duration'] as num?)?.toInt() ?? 0;

    return TrackModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Unknown Title',
      artist: artistMap?['name']?.toString() ?? 'Unknown Artist',
      album: albumMap?['title']?.toString() ?? '',
      artworkUrl: cover.toString(),
      durationMs: durationSec * 1000,
    );
  }

  /// Membersihkan noise teks YouTube dari judul lagu (mis. `(Official Video)`, `(Lyrics)`).
  static String cleanTitle(String raw) {
    var title = raw;
    final regexes = [
      RegExp(r'\([^)]*?(official|video|audio|4k|hd|hq|lyrics|lyric|lirik|letra|remastered|visualizer|music\s*video|mv|sub\.?\s*indonesian?|terjemahan|legendado)[^)]*?\)', caseSensitive: false),
      RegExp(r'\[[^\]]*?(official|video|audio|4k|hd|hq|lyrics|lyric|lirik|letra|remastered|visualizer|music\s*video|mv|sub\.?\s*indonesian?|terjemahan|legendado|best\s*live)[^\]]*?\]', caseSensitive: false),
      RegExp(r'\|\s*(mtv\s*music|lirik\s*terjemahan|sub\.?\s*indonesian?).*$', caseSensitive: false),
      // Kredit fitur dalam kurung, mis. "(feat. X)" atau "[ft. X]".
      RegExp(r'\s*[\(\[]\s*(?:ft|feat)\.?\s*[^)\]]*[\)\]]', caseSensitive: false),
      // Kredit fitur di akhir judul, mis. "Song ft. X" atau "Song feat X".
      // Wajib didahului spasi agar kata seperti "After" tidak ikut terpotong.
      RegExp(r'\s+(?:ft|feat)\.?\s*.*$', caseSensitive: false),
      // Jaring pengaman untuk kurung fitur yang tidak tertutup.
      RegExp(r'\s*[\(\[]\s*(?:ft|feat)\.?\s*.*$', caseSensitive: false),
    ];
    for (final reg in regexes) {
      title = title.replaceAll(reg, '');
    }
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Membersihkan nama artis dari channel YouTube (mis. `Oasis - Topic` -> `Oasis`).
  static String cleanArtist(String raw) {
    var artist = raw;
    artist = artist.replaceAll(RegExp(r'\s*-\s*topic$', caseSensitive: false), '');
    artist = artist.replaceAll(RegExp(r'vevo$', caseSensitive: false), '');
    return artist.trim();
  }

  /// Membedah judul video YouTube menjadi nama artis dan judul lagu bersih.
  static ({String artist, String title}) parseYouTubeMetadata(String rawTitle, String author) {
    final cleanedAuthor = cleanArtist(author);
    if (rawTitle.contains(' - ')) {
      final parts = rawTitle.split(' - ');
      final possibleArtist = cleanArtist(parts[0].trim());
      final possibleTitle = cleanTitle(parts.sublist(1).join(' - ').trim());
      return (
        artist: possibleArtist.isNotEmpty ? possibleArtist : cleanedAuthor,
        title: possibleTitle.isNotEmpty ? possibleTitle : cleanTitle(rawTitle),
      );
    }
    return (
      artist: cleanedAuthor.isNotEmpty ? cleanedAuthor : 'YouTube',
      title: cleanTitle(rawTitle),
    );
  }

  String toJson() => json.encode(toMap());

  factory TrackModel.fromJson(String source) =>
      TrackModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrackModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
