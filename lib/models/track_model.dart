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

  const TrackModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.durationMs,
    this.youtubeId,
    this.localPath,
  });

  bool get isDownloaded => localPath != null && localPath!.isNotEmpty;

  String get formattedDuration {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
