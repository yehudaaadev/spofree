import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track_model.dart';
import '../services/download_service.dart';
import '../services/lyrics_service.dart';
import '../services/music_service.dart';

class PlayerProvider with ChangeNotifier {
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();
  late final AudioPlayer _player;

  final MusicService _musicService = MusicService();
  final LyricsService _lyricsService = LyricsService();
  final DownloadService _downloadService = DownloadService();

  static const String _recentKey = 'spotube_recently_played';

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

  // Premium Features: Speed, Sleep Timer, Recently Played, Audio Quality, Autoplay
  double _playbackSpeed = 1.0;
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _sleepAtSongEnd = false;
  List<TrackModel> _recentlyPlayed = [];
  String _audioQuality = 'Maksimal (320 kbps High Quality)';
  bool _autoplayEnabled = true;
  bool _isFetchingAutoplay = false;

  // Crossfade
  int _crossfadeSeconds = 0;
  bool _isCrossfading = false;

  // Pitch Shifting & Karaoke
  double _pitch = 1.0;
  int _pitchSemitones = 0;
  String _audioPreset = 'Normal';

  // Equalizer & Bass Boost
  bool _equalizerEnabled = false;
  String _equalizerPreset = 'Flat';
  double _bassBoostGain = 0.0;
  List<double> _customBandGains = [0.0, 0.0, 0.0, 0.0, 0.0];

  static const Map<String, List<double>> equalizerPresets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [4.5, 3.0, 0.0, 0.0, -1.0],
    'Rock': [3.5, 2.0, -0.5, 2.5, 4.0],
    'Pop': [-1.0, 1.5, 3.5, 2.0, -1.0],
    'Vocal': [-2.0, 0.0, 3.5, 3.0, 1.5],
    'Acoustic': [2.5, 1.5, 0.5, 1.5, 3.0],
    'Electronic': [4.0, 2.5, -1.0, 1.5, 3.5],
  };

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  PlayerProvider() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_equalizer, _loudnessEnhancer],
      ),
    );
    _initPlayer();
    _loadRecentlyPlayed();
    _initEqualizer();
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

  double get playbackSpeed => _playbackSpeed;
  bool get hasActiveSleepTimer => _sleepTimer != null || _sleepAtSongEnd;
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;
  bool get sleepAtSongEnd => _sleepAtSongEnd;
  List<TrackModel> get recentlyPlayed => _recentlyPlayed;
  String get audioQuality => _audioQuality;
  bool get autoplayEnabled => _autoplayEnabled;

  int get crossfadeSeconds => _crossfadeSeconds;
  double get pitch => _pitch;
  int get pitchSemitones => _pitchSemitones;
  String get audioPreset => _audioPreset;

  bool get equalizerEnabled => _equalizerEnabled;
  String get equalizerPreset => _equalizerPreset;
  double get bassBoostGain => _bassBoostGain;
  List<double> get customBandGains => _customBandGains;

  void _initPlayer() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        if (_sleepAtSongEnd) {
          pause();
          _sleepAtSongEnd = false;
          notifyListeners();
        } else {
          next();
        }
      }
      notifyListeners();
    });

    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      if (_crossfadeSeconds > 0 &&
          _duration > Duration(seconds: _crossfadeSeconds + 2) &&
          pos >= _duration - Duration(seconds: _crossfadeSeconds) &&
          !_isCrossfading &&
          _isPlaying &&
          _currentIndex + 1 < _queue.length) {
        _triggerCrossfade();
      }
      notifyListeners();
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _duration = dur;
        notifyListeners();
      }
    });
  }

  Future<void> _initEqualizer() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _equalizer.setEnabled(_equalizerEnabled);
        await _loudnessEnhancer.setEnabled(_bassBoostGain > 0);
      } catch (_) {}
    }
  }

  Future<void> _triggerCrossfade() async {
    _isCrossfading = true;
    final stepDuration = Duration(milliseconds: (_crossfadeSeconds * 1000 ~/ 5).clamp(100, 1000));
    for (double v = 1.0; v >= 0.1; v -= 0.2) {
      await _player.setVolume(v.clamp(0.0, 1.0));
      await Future.delayed(stepDuration);
    }
    await next();
    for (double v = 0.2; v <= 1.0; v += 0.2) {
      await _player.setVolume(v.clamp(0.0, 1.0));
      await Future.delayed(const Duration(milliseconds: 200));
    }
    await _player.setVolume(1.0);
    _isCrossfading = false;
  }

  Future<void> _loadRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    _autoplayEnabled = prefs.getBool('spotube_autoplay') ?? true;
    final raw = prefs.getStringList(_recentKey) ?? [];
    _recentlyPlayed = raw.map((item) {
      try {
        return TrackModel.fromMap(json.decode(item) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<TrackModel>().toList();
    notifyListeners();
  }

  Future<void> setAutoplay(bool value) async {
    _autoplayEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spotube_autoplay', value);
  }

  Future<void> toggleAutoplay() async {
    await setAutoplay(!_autoplayEnabled);
  }

  Future<void> _recordRecentlyPlayed(TrackModel track) async {
    _recentlyPlayed.removeWhere((t) => t.id == track.id);
    _recentlyPlayed.insert(0, track);
    if (_recentlyPlayed.length > 25) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 25);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final raw = _recentlyPlayed.map((t) => json.encode(t.toMap())).toList();
    await prefs.setStringList(_recentKey, raw);
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

    _recordRecentlyPlayed(track);
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
        final streamUrl = await _musicService.resolveAudioStream(track, quality: _audioQuality);
        final audioSource = AudioSource.uri(
          Uri.parse(streamUrl),
          tag: mediaItem,
        );
        await _player.setAudioSource(audioSource);
      }

      await _player.setSpeed(_playbackSpeed);
      try {
        await _player.setPitch(_pitch);
      } catch (_) {}
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

  Future<void> resume() async => await _player.play();
  Future<void> pause() async => await _player.pause();

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration pos) async => await _player.seek(pos);

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffle && _queue.length > 1) {
      final nextIdx = (DateTime.now().millisecond) % _queue.length;
      await playTrack(_queue[nextIdx], queue: _queue);
      return;
    }

    if (_currentIndex + 1 < _queue.length) {
      await playTrack(_queue[_currentIndex + 1], queue: _queue);
    } else if (_loopMode == LoopMode.all) {
      await playTrack(_queue[0], queue: _queue);
    } else if (_autoplayEnabled && _currentTrack != null && !_isFetchingAutoplay) {
      _isFetchingAutoplay = true;
      try {
        final related = await _musicService.getRelatedTracks(_currentTrack!);
        if (related.isNotEmpty) {
          final existingIds = _queue.map((t) => t.id).toSet();
          final newTracks = related.where((t) => !existingIds.contains(t.id)).toList();
          if (newTracks.isNotEmpty) {
            _queue.addAll(newTracks);
            notifyListeners();
            if (_currentIndex + 1 < _queue.length) {
              await playTrack(_queue[_currentIndex + 1], queue: _queue);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Autoplay fetch error: $e');
      } finally {
        _isFetchingAutoplay = false;
      }
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

  void addToQueue(TrackModel track) {
    _queue.add(track);
    notifyListeners();
  }

  void addTracksToQueue(List<TrackModel> tracks) {
    _queue.addAll(tracks);
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length || newIndex < 0 || newIndex > _queue.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    if (_currentTrack != null) {
      _currentIndex = _queue.indexWhere((t) => t.id == _currentTrack!.id);
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (_currentTrack != null) {
        _currentIndex = _queue.indexWhere((t) => t.id == _currentTrack!.id);
      }
      notifyListeners();
    }
  }

  void clearQueue() {
    if (_currentTrack != null) {
      _queue = [_currentTrack!];
      _currentIndex = 0;
    } else {
      _queue.clear();
      _currentIndex = -1;
    }
    notifyListeners();
  }

  // Crossfade Control
  void setCrossfadeSeconds(int seconds) {
    _crossfadeSeconds = seconds;
    notifyListeners();
  }

  // Speed Control
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setSpeed(speed);
    notifyListeners();
  }

  // Pitch & Karaoke Controls
  Future<void> setPitchSemitones(int semitones) async {
    _pitchSemitones = semitones.clamp(-6, 6);
    _pitch = math.pow(2.0, _pitchSemitones / 12.0).toDouble();
    _audioPreset = 'Custom';
    try {
      await _player.setPitch(_pitch);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> applyAudioPreset(String preset) async {
    _audioPreset = preset;
    switch (preset) {
      case 'Normal':
        _playbackSpeed = 1.0;
        _pitchSemitones = 0;
        break;
      case 'Karaoke Vokal Rendah':
        _playbackSpeed = 1.0;
        _pitchSemitones = -2;
        break;
      case 'Karaoke Vokal Tinggi':
        _playbackSpeed = 1.0;
        _pitchSemitones = 2;
        break;
      case 'Slowed + Reverb':
        _playbackSpeed = 0.85;
        _pitchSemitones = -2;
        break;
      case 'Nightcore / Speed Up':
        _playbackSpeed = 1.25;
        _pitchSemitones = 3;
        break;
      default:
        break;
    }
    _pitch = math.pow(2.0, _pitchSemitones / 12.0).toDouble();
    await _player.setSpeed(_playbackSpeed);
    try {
      await _player.setPitch(_pitch);
    } catch (_) {}
    notifyListeners();
  }

  // Equalizer & Bass Boost Controls
  Future<void> setEqualizerEnabled(bool enabled) async {
    _equalizerEnabled = enabled;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _equalizer.setEnabled(enabled);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setEqualizerPreset(String preset) async {
    _equalizerPreset = preset;
    final gains = equalizerPresets[preset];
    if (gains != null) {
      _customBandGains = List.from(gains);
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final params = await _equalizer.parameters;
          for (int i = 0; i < params.bands.length && i < gains.length; i++) {
            await params.bands[i].setGain(gains[i]);
          }
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<void> setBandGain(int index, double gain) async {
    if (index >= 0 && index < _customBandGains.length) {
      _customBandGains[index] = gain;
      _equalizerPreset = 'Custom';
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final params = await _equalizer.parameters;
          if (index < params.bands.length) {
            await params.bands[index].setGain(gain);
          }
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> setBassBoost(double gain) async {
    _bassBoostGain = gain.clamp(0.0, 1.0);
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _loudnessEnhancer.setEnabled(_bassBoostGain > 0);
        await _loudnessEnhancer.setTargetGain(_bassBoostGain * 1000.0);
      } catch (_) {}
    }
    notifyListeners();
  }

  // Sleep Timer with smooth fade-out
  void setSleepTimer(Duration? duration, {bool atSongEnd = false}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _sleepAtSongEnd = atSongEnd;

    if (duration != null && !atSongEnd) {
      _sleepTimerEndTime = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, _executeSleepFadeOut);
    }
    notifyListeners();
  }

  Future<void> _executeSleepFadeOut() async {
    for (double vol = 1.0; vol >= 0.0; vol -= 0.2) {
      await _player.setVolume(vol.clamp(0.0, 1.0));
      await Future.delayed(const Duration(milliseconds: 600));
    }
    await pause();
    await _player.setVolume(1.0);
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    notifyListeners();
  }

  void setAudioQuality(String quality) {
    _audioQuality = quality;
    notifyListeners();
  }

  // Download Operation
  Future<TrackModel?> downloadCurrentTrack() async {
    if (_currentTrack == null || _isDownloading) return null;

    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final streamUrl = await _musicService.resolveAudioStream(_currentTrack!, quality: _audioQuality);
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
    _sleepTimer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    _musicService.dispose();
    super.dispose();
  }
}
