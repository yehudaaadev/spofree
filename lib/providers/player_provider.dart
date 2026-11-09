import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../models/track_model.dart';
import '../services/download_service.dart';
import '../services/lyrics_service.dart';
import '../services/music_service.dart';

class PlayerProvider with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final MusicService _musicService = MusicService();
  final LyricsService _lyricsService = LyricsService();
  final DownloadService _downloadService = DownloadService();

  TrackModel? _currentTrack;
  List<TrackModel> _queue = [];
  int _currentIndex = -1;

  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  List<LyricsLine> _lyrics = [];
  bool _isLoadingLyrics = false;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  PlayerProvider() {
    _initPlayer();
  }

  TrackModel? get currentTrack => _currentTrack;
  List<TrackModel> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isLoadingAudio => _isLoadingAudio;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  List<LyricsLine> get lyrics => _lyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  void _initPlayer() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      notifyListeners();
    });

    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  Future<void> playTrack(TrackModel track, {List<TrackModel>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List.from(queue);
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_currentIndex == -1) {
        _queue.insert(0, track);
        _currentIndex = 0;
      }
    } else if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    }

    _currentTrack = track;
    _isLoadingAudio = true;
    _position = Duration.zero;
    _duration = Duration(milliseconds: track.durationMs);
    notifyListeners();

    _fetchLyrics(track);

    try {
      final mediaItem = MediaItem(
        id: track.id,
        album: track.album.isNotEmpty ? track.album : 'Single',
        title: track.title,
        artist: track.artist,
        artUri: track.artworkUrl.isNotEmpty ? Uri.tryParse(track.artworkUrl) : null,
        duration: Duration(milliseconds: track.durationMs),
      );

      final isLocal = track.localPath != null && await File(track.localPath!).exists();

      if (isLocal) {
        final audioSource = AudioSource.file(
          track.localPath!,
          tag: mediaItem,
        );
        await _player.setAudioSource(audioSource);
      } else {
        final streamUrl = await _musicService.resolveAudioStream(track);
        final audioSource = AudioSource.uri(
          Uri.parse(streamUrl),
          tag: mediaItem,
        );
        await _player.setAudioSource(audioSource);
      }

      await _player.play();
    } catch (e) {
      debugPrint('Playback error: $e');
    } finally {
      _isLoadingAudio = false;
      notifyListeners();
    }
  }

  Future<void> _fetchLyrics(TrackModel track) async {
    _isLoadingLyrics = true;
    _lyrics = [];
    notifyListeners();

    final result = await _lyricsService.fetchLyrics(
      title: track.title,
      artist: track.artist,
    );
    _lyrics = result;
    _isLoadingLyrics = false;
    notifyListeners();
  }

  int get currentLyricsIndex {
    if (_lyrics.isEmpty) return -1;
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (_position >= _lyrics[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffle) {
      final nextIdx = (DateTime.now().millisecond) % _queue.length;
      await playTrack(_queue[nextIdx], queue: _queue);
      return;
    }

    if (_currentIndex + 1 < _queue.length) {
      await playTrack(_queue[_currentIndex + 1], queue: _queue);
    } else if (_loopMode == LoopMode.all) {
      await playTrack(_queue[0], queue: _queue);
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 4) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex - 1 >= 0) {
      await playTrack(_queue[_currentIndex - 1], queue: _queue);
    } else {
      await seek(Duration.zero);
    }
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
      _player.setLoopMode(LoopMode.all);
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
      _player.setLoopMode(LoopMode.one);
    } else {
      _loopMode = LoopMode.off;
      _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  Future<TrackModel?> downloadCurrentTrack() async {
    if (_currentTrack == null || _isDownloading) return null;

    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final streamUrl = await _musicService.resolveAudioStream(_currentTrack!);
      final downloadedTrack = await _downloadService.downloadTrack(
        track: _currentTrack!,
        audioStreamUrl: streamUrl,
        onProgress: (p) {
          _downloadProgress = p;
          notifyListeners();
        },
      );

      _currentTrack = downloadedTrack;
      if (_currentIndex >= 0 && _currentIndex < _queue.length) {
        _queue[_currentIndex] = downloadedTrack;
      }
      return downloadedTrack;
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    _musicService.dispose();
    super.dispose();
  }
}
