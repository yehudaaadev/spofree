import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track_model.dart';
import '../services/download_service.dart';
import '../services/lyrics_service.dart';
import '../services/music_service.dart';
import '../services/sponsorblock_service.dart';
import '../services/youtube_stream_source.dart';

/// Otak aplikasi pemutar.
///
/// Meny STATE playback (antrean, posisi, durasi, efek) dan dikonsumsi seluruh
/// widget melalui `provider`. Semua operasi playback diserialisasi melalui
/// [_playChain] sehingga permintaan yang tumpang tindih (mis. tap cepat pada
/// beberapa lagu) tidak saling menimpa sumber audio.
class PlayerProvider with ChangeNotifier {
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();
  late final AudioPlayer _player;

  final MusicService _musicService = MusicService.instance;
  final LyricsService _lyricsService = LyricsService();
  final DownloadService _downloadService = DownloadService();
  final SponsorBlockService _sponsorBlockService = SponsorBlockService();

  final math.Random _random = math.Random();

  static const String _recentKey = 'spotube_recently_played';

  /// Batas jumlah lagu hasil autoplay yang ditambahkan ke antrean.
  static const int _maxAutoplayTracks = 15;

  /// Batas panjang antrean agar tidak membengkak tanpa batas.
  static const int _maxQueueLength = 300;

  /// Batas waktu menunggu sumber audio selesai dimuat.
  static const Duration _loadTimeout = Duration(seconds: 12);

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
  bool _mixChartEnabled = true;

  /// Id lagu yang sudah diputar sebagai bagian radio (anti pengulangan).
  final Set<String> _radioHistory = {};

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

  // SponsorBlock
  bool _sponsorBlockEnabled = true;
  List<SponsorSegment> _activeSegments = [];
  Duration? _lastSkippedUntil;
  String? _skippedSegmentNotice;

  // Audio Balance & Mono
  double _balance = 0.0;

  // Dua Lapis Antrean ("Play Next" vs Context Queue)
  int _userQueueCount = 0;

  // Serialisasi playback & penanganan error.
  Future<void> _playChain = Future<void>.value();
  int _playToken = 0;
  String? _errorMessage;

  /// Id lagu yang sudah dicoba ulang dengan stream MP4/AAC.
  ///
  /// Sebagian perangkat lama gagal mendekode Opus/WebM. Untuk lagu yang
  /// bermasalah, pemutaran dicoba sekali lagi memakai kontainer MP4 (AAC).
  String? _mp4FallbackTrackId;

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
  StreamSubscription? _errorSub;
  StreamSubscription? _becomingNoisySub;
  StreamSubscription? _interruptionSub;
  bool _playInterrupted = false;

  PlayerProvider() {
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [_equalizer, _loudnessEnhancer],
      ),
    );
    _initPlayer();
    _initAudioSession();
    _loadRecentlyPlayed();
    _initEqualizer();
    _loadPreferences();
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
  bool get mixChartEnabled => _mixChartEnabled;

  int get crossfadeSeconds => _crossfadeSeconds;
  double get pitch => _pitch;
  int get pitchSemitones => _pitchSemitones;
  String get audioPreset => _audioPreset;

  bool get equalizerEnabled => _equalizerEnabled;
  String get equalizerPreset => _equalizerPreset;
  double get bassBoostGain => _bassBoostGain;
  List<double> get customBandGains => _customBandGains;

  bool get sponsorBlockEnabled => _sponsorBlockEnabled;
  List<SponsorSegment> get activeSegments => _activeSegments;
  String? get skippedSegmentNotice => _skippedSegmentNotice;
  double get balance => _balance;
  int get userQueueCount => _userQueueCount;

  /// Pesan error terakhir yang perlu ditampilkan ke pengguna.
  String? get errorMessage => _errorMessage;

  /// Hapus pesan error setelah ditampilkan.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  String? _retryTrackId;
  int _retryAttempts = 0;

  /// Memutar ulang lagu yang sedang aktif.
  ///
  /// Dipakai oleh tombol "Coba lagi" ketika pemuatan stream gagal.
  Future<void> retryCurrentTrack() async {
    final track = _currentTrack;
    if (track == null) return;
    _retryAttempts = 0;
    await playTrack(
      track,
      queue: _queue,
      initialPosition: _position,
      explicitIndex: _currentIndex >= 0 ? _currentIndex : null,
      forceStreamRefresh: true,
    );
  }

  /// Kontainer yang dipakai untuk stream [track].
  String? _preferredContainerFor(TrackModel track) {
    return _mp4FallbackTrackId == track.id ? 'mp4' : null;
  }

  /// Mencoba memulihkan pemutaran [track] secara otomatis bila terjadi kendala stream.
  ///
  /// Dibatasi maksimal 2 kali percobaan per lagu untuk mencegah pengulangan
  /// tanpa henti bila koneksi internet benar-benar terputus.
  bool _scheduleMp4Fallback(TrackModel track, {Duration? resumePosition}) {
    if (_retryTrackId != track.id) {
      _retryTrackId = track.id;
      _retryAttempts = 0;
    }
    if (_retryAttempts >= 2) {
      return false;
    }
    _retryAttempts++;
    _mp4FallbackTrackId = track.id;
    final currentIdx = _currentIndex;
    unawaited(playTrack(
      track,
      queue: _queue,
      initialPosition: resumePosition,
      explicitIndex: currentIdx >= 0 ? currentIdx : null,
      forceStreamRefresh: true,
    ));
    return true;
  }

  /// Memantau apakah sumber audio berhasil dimuat dalam [_loadTimeout].
  ///
  /// Tanpa ini, sumber yang menggantung (mis. server tidak pernah selesai
  /// mengirim data) membuat posisi playback diam di detik 0 tanpa penjelasan.
  Future<void> _watchLoadTimeout(int token, TrackModel track) async {
    await Future.delayed(_loadTimeout);
    if (token != _playToken) return;
    if (_isLoadingAudio && _position == Duration.zero) {
      _isLoadingAudio = false;
      _setError(
        'Lagu "${track.title}" tidak dapat dimuat. Periksa koneksi lalu coba lagi.',
      );
    }
  }

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

    // just_audio melaporkan kegagalan pemutaran lewat errorStream.
    _errorSub = _player.errorStream.listen((exception) {
      debugPrint('[Player] error stream: $exception');
      _isLoadingAudio = false;
      final track = _currentTrack;
      final currentPos = _position;
      if (track != null && _scheduleMp4Fallback(track, resumePosition: currentPos)) {
        // Stream utama gagal: coba kontainer MP4/AAC lebih dulu sebelum
        // menampilkan pesan error, memulihkan posisi lagu terakhir.
        return;
      }
      _setError(
        'Pemutaran terhenti: ${exception.message ?? 'kesalahan audio tak diketahui'}.',
      );
    });

    _positionSub = _player.positionStream.listen((pos) {
      _position = pos;
      if (_sponsorBlockEnabled && _activeSegments.isNotEmpty) {
        _checkSponsorSegments(pos);
      }
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

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
        if (_isPlaying) {
          pause();
        }
      });
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_isPlaying) {
                _playInterrupted = true;
                pause();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              break;
            case AudioInterruptionType.pause:
              if (_playInterrupted) {
                _playInterrupted = false;
                resume();
              }
              break;
            case AudioInterruptionType.unknown:
              _playInterrupted = false;
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('[Player] gagal menginisialisasi listener audio session: $e');
    }
  }

  Future<void> _initEqualizer() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _equalizer.setEnabled(_equalizerEnabled);
        await _loudnessEnhancer.setEnabled(_bassBoostGain > 0);
      } catch (e) {
        debugPrint('[Player] equalizer init gagal: $e');
      }
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('spotube_sponsorblock')) {
        _sponsorBlockEnabled = prefs.getBool('spotube_sponsorblock') ?? true;
      }
      if (prefs.containsKey('spotube_balance')) {
        _balance = prefs.getDouble('spotube_balance') ?? 0.0;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Player] gagal memuat preferensi: $e');
    }
  }

  void _checkSponsorSegments(Duration pos) {
    if (_lastSkippedUntil != null && pos < _lastSkippedUntil!) {
      return;
    }
    for (final seg in _activeSegments) {
      if (pos >= seg.start && pos < seg.end - const Duration(milliseconds: 300)) {
        _lastSkippedUntil = seg.end;
        seek(seg.end);
        _skippedSegmentNotice =
            'Melewati ${seg.category.label} (${seg.durationString})';
        notifyListeners();
        Future.delayed(const Duration(seconds: 4), () {
          if (_skippedSegmentNotice != null) {
            _skippedSegmentNotice = null;
            notifyListeners();
          }
        });
        break;
      }
    }
  }

  Future<void> _loadSponsorSegments(TrackModel track) async {
    _activeSegments = [];
    _lastSkippedUntil = null;
    final ytId = track.youtubeId ?? MusicService.getCachedVideoId(track.id);
    if (ytId != null && ytId.isNotEmpty) {
      final segments = await _sponsorBlockService.getSegments(ytId);
      if (_currentTrack?.id == track.id) {
        _activeSegments = segments;
        notifyListeners();
      }
    }
  }

  Future<void> _triggerCrossfade() async {
    if (_isCrossfading) return;
    _isCrossfading = true;
    try {
      final stepDuration =
          Duration(milliseconds: (_crossfadeSeconds * 1000 ~/ 5).clamp(100, 1000));
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
    } catch (e) {
      debugPrint('[Player] crossfade gagal: $e');
      await _player.setVolume(1.0);
    } finally {
      _isCrossfading = false;
    }
  }

  Future<void> _loadRecentlyPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    _autoplayEnabled = prefs.getBool('spotube_autoplay') ?? true;
    _mixChartEnabled = prefs.getBool('spotube_radio_mix_chart') ?? true;
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

  /// Aktifkan/Nonaktifkan pencampuran lagu chart global ke dalam Track Radio.
  Future<void> setMixChart(bool value) async {
    _mixChartEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spotube_radio_mix_chart', value);
  }

  Future<void> _recordRecentlyPlayed(TrackModel track) async {
    _recentlyPlayed.removeWhere((t) => t.id == track.id);
    _recentlyPlayed.insert(0, track);
    if (_recentlyPlayed.length > 25) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, 25);
    }

    // Simpan id yang sudah diputar agar Track Radio tidak mengulang lagu.
    _radioHistory.add(track.id);
    if (_radioHistory.length > 200) {
      _radioHistory.remove(_radioHistory.first);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final raw = _recentlyPlayed.map((t) => json.encode(t.toMap())).toList();
    await prefs.setStringList(_recentKey, raw);
  }

  /// Memutar sebuah lagu.
  ///
  /// Permintaan diantrikan pada [_playChain] sehingga hanya satu pergantian
  /// sumber audio yang berjalan pada satu waktu. Permintaan yang sudah
  /// digantikan (mis. pengguna menekan lagu lain sebelum lagu sebelumnya selesai
  /// dimuat) dibatalkan secara halus.
  Future<void> playTrack(
    TrackModel track, {
    List<TrackModel>? queue,
    Duration? initialPosition,
    int? explicitIndex,
    bool forceStreamRefresh = false,
  }) {
    final token = ++_playToken;
    final completer = Completer<void>();

    _playChain = _playChain.then((_) async {
      try {
        if (token != _playToken) return; // Permintaan sudah usang.
        await _playTrackInternal(
          track,
          queue: queue,
          token: token,
          initialPosition: initialPosition,
          explicitIndex: explicitIndex,
          forceStreamRefresh: forceStreamRefresh,
        );
      } catch (e, st) {
        debugPrint('[Player] playTrack gagal: $e\n$st');
        if (token == _playToken) {
          _setError('Gagal memutar "${track.title}".');
        }
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });

    return completer.future;
  }

  Future<void> _playTrackInternal(
    TrackModel track, {
    List<TrackModel>? queue,
    required int token,
    Duration? initialPosition,
    int? explicitIndex,
    bool forceStreamRefresh = false,
  }) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List.from(queue);
      if (explicitIndex != null &&
          explicitIndex >= 0 &&
          explicitIndex < _queue.length &&
          _queue[explicitIndex].id == track.id) {
        _currentIndex = explicitIndex;
      } else {
        _currentIndex = _queue.indexWhere((t) => t.id == track.id);
        if (_currentIndex == -1) {
          _queue.insert(0, track);
          _currentIndex = 0;
        }
      }
    } else if (explicitIndex != null &&
        explicitIndex >= 0 &&
        explicitIndex < _queue.length &&
        _queue[explicitIndex].id == track.id) {
      _currentIndex = explicitIndex;
    } else if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
      _currentIndex = _queue.length - 1;
    } else {
      _currentIndex = _queue.indexWhere((t) => t.id == track.id);
    }

    _currentTrack = track;
    _isLoadingAudio = true;
    _position = initialPosition ?? Duration.zero;
    _duration = Duration(milliseconds: track.durationMs);

    // Cadangan MP4/AAC hanya berlaku untuk lagu yang bermasalah saja.
    if (_mp4FallbackTrackId != null && _mp4FallbackTrackId != track.id) {
      _mp4FallbackTrackId = null;
    }
    notifyListeners();

    // Penjaga: kalau sumber audio menggantung, posisi playback diam di detik 0
    // tanpa pesan. Penjaga ini mengubahnya menjadi error yang bisa ditindaklanjuti.
    unawaited(_watchLoadTimeout(token, track));

    _recordRecentlyPlayed(track);
    _fetchLyrics(track);
    if (_userQueueCount > 0) {
      _userQueueCount--;
    }
    _loadSponsorSegments(track);

    try {
      final mediaItem = MediaItem(
        id: track.id,
        album: track.album.isNotEmpty ? track.album : 'Single',
        title: track.title,
        artist: track.artist,
        artUri: track.artworkUrl.isNotEmpty ? Uri.tryParse(track.artworkUrl) : null,
        duration: Duration(milliseconds: track.durationMs),
      );

      final isLocal =
          track.localPath != null && await File(track.localPath!).exists();

      if (isLocal) {
        await _player.setAudioSource(
          AudioSource.file(track.localPath!, tag: mediaItem),
        );
      } else {
        await _setStreamSource(
          track,
          mediaItem,
          forceRefresh: forceStreamRefresh,
        );
      }

      if (token != _playToken) return;

      if (initialPosition != null && initialPosition > Duration.zero) {
        await _player.seek(initialPosition);
      }

      await _player.setSpeed(_playbackSpeed);
      try {
        await _player.setPitch(_pitch);
      } catch (e) {
        debugPrint('[Player] setPitch gagal: $e');
      }

      // Future `play()` baru selesai saat pemutaran berakhir, jadi future itu
      // TIDAK boleh awaited di dalam [_playChain]. Kalau di-await, rantai
      // terkunci sampai lagu selesai dan permintaan lagu berikutnya tidak
      // pernah dijalankan.
      unawaited(_player.play().catchError((Object e, StackTrace st) {
        debugPrint('[Player] play gagal: $e');
      }));

      // Preload lagu berikutnya di antrean secara diam-diam agar transisi instan
      if (_currentIndex + 1 < _queue.length) {
        unawaited(_musicService.preloadTrackStream(
          _queue[_currentIndex + 1],
          quality: _audioQuality,
        ));
      }
    } catch (e, st) {
      debugPrint('[Player] pemutaran gagal: $e\n$st');
      if (token == _playToken) {
        final currentPos = _position;
        if (!_scheduleMp4Fallback(track, resumePosition: currentPos)) {
          _setError('Gagal memutar "${track.title}".');
        }
      }
    } finally {
      if (token == _playToken) {
        _isLoadingAudio = false;
        notifyListeners();
      }
    }
  }

  /// Mengatur sumber audio streaming.
  ///
  /// Memprioritaskan direct progressive stream (tag 18 MP4) yang didukung penuh
  /// oleh ExoPlayer tanpa jeda proxy dan bebas dari pemblokiran HTTP 403 CDN.
  Future<void> _setStreamSource(
    TrackModel track,
    MediaItem mediaItem, {
    bool forceRefresh = false,
  }) async {
    final resolved = await _musicService.resolveAudioStreamInfo(
      track,
      quality: _audioQuality,
      forceRefresh: forceRefresh,
      preferredContainer: _preferredContainerFor(track),
      preferProgressive: true,
    );

    if (resolved.isDirectProgressive) {
      final source = AudioSource.uri(
        Uri.parse(resolved.url),
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        },
        tag: mediaItem,
      );
      await _player.setAudioSource(source);
    } else {
      final source = YouTubeStreamSource(
        track: track,
        quality: _audioQuality,
        musicService: _musicService,
        preferredContainer: _preferredContainerFor(track),
        tag: mediaItem,
      );
      await _player.setAudioSource(source);
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

  Future<void> seek(Duration pos) async {
    if (_lastSkippedUntil != null && pos < _lastSkippedUntil!) {
      _lastSkippedUntil = null;
    }
    await _player.seek(pos);
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;

    if (_isShuffle && _queue.length > 1) {
      final nextIdx = _randomShuffleIndex();
      if (nextIdx >= 0) {
        await playTrack(_queue[nextIdx], queue: _queue, explicitIndex: nextIdx);
        return;
      }
    }

    if (_currentIndex + 1 < _queue.length) {
      final nextIdx = _currentIndex + 1;
      await playTrack(_queue[nextIdx], queue: _queue, explicitIndex: nextIdx);
    } else if (_loopMode == LoopMode.all) {
      await playTrack(_queue[0], queue: _queue, explicitIndex: 0);
    } else if (_autoplayEnabled && _currentTrack != null && !_isFetchingAutoplay) {
      _isFetchingAutoplay = true;
      try {
        // Track Radio: daftar dari Deezer artist radio (genre/era based),
        // bukan sekadar lagu dengan nama artis yang sama.
        final radio = await _musicService.getRadioTracks(
          _currentTrack!,
          limit: _maxAutoplayTracks,
        );

        final existingIds = _queue.map((t) => t.id).toSet();
        final batch = <TrackModel>[];

        for (final candidate in radio) {
          if (batch.length >= _maxAutoplayTracks) break;
          if (existingIds.contains(candidate.id)) continue;
          if (_radioHistory.contains(candidate.id)) continue;
          if (batch.any((b) => b.id == candidate.id)) continue;
          batch.add(candidate);
        }

        // Campur beberapa lagu chart global agar radio tidak monoton.
        if (_mixChartEnabled && batch.length < _maxAutoplayTracks) {
          final chart = await _musicService.getChartTracks();
          for (final candidate in chart) {
            if (batch.length >= _maxAutoplayTracks) break;
            if (existingIds.contains(candidate.id)) continue;
            if (_radioHistory.contains(candidate.id)) continue;
            if (batch.any((b) => b.id == candidate.id)) continue;
            batch.add(candidate);
          }
        }

        if (batch.isNotEmpty) {
          _queue.addAll(batch);
          _trimQueue();
          notifyListeners();
          if (_currentIndex + 1 < _queue.length) {
            final nextIdx = _currentIndex + 1;
            await playTrack(_queue[nextIdx], queue: _queue, explicitIndex: nextIdx);
            return;
          }
        }
      } catch (e) {
        debugPrint('[Player] Track Radio gagal: $e');
      } finally {
        _isFetchingAutoplay = false;
      }
    }
  }

  /// Memilih indeks acak yang berbeda dari lagu sedang diputar.
  ///
  /// Gunakan generator angka acak sejati (bukan `DateTime.now().millisecond`)
  /// agar lagu yang sama tidak terpilih berulang kali.
  int _randomShuffleIndex() {
    if (_queue.length < 2) return -1;
    final candidates = <int>[];
    for (int i = 0; i < _queue.length; i++) {
      if (i != _currentIndex) candidates.add(i);
    }
    if (candidates.isEmpty) return -1;
    return candidates[_random.nextInt(candidates.length)];
  }

  /// Membatasi panjang antrean dengan membuang lagu terlama (kecuali yang
  /// sedang diputar).
  void _trimQueue() {
    if (_queue.length <= _maxQueueLength) return;
    final excess = _queue.length - _maxQueueLength;
    final removable = <int>[];
    for (int i = 0; i < _queue.length; i++) {
      if (i != _currentIndex) removable.add(i);
      if (removable.length == excess) break;
    }
    for (final index in removable.reversed) {
      _queue.removeAt(index);
    }
    if (_currentTrack != null) {
      _currentIndex = _queue.indexWhere((t) => t.id == _currentTrack!.id);
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;

    if (_position.inSeconds > 4) {
      await seek(Duration.zero);
      return;
    }

    if (_currentIndex - 1 >= 0) {
      final prevIdx = _currentIndex - 1;
      await playTrack(_queue[prevIdx], queue: _queue, explicitIndex: prevIdx);
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

  /// Memutar track ini persis setelah lagu yang sedang aktif selesai ("Play Next").
  void playNext(TrackModel track) {
    if (_queue.isEmpty) {
      playTrack(track, queue: [track]);
      return;
    }
    final insertIndex = (_currentIndex + 1 + _userQueueCount).clamp(0, _queue.length);
    _queue.insert(insertIndex, track);
    _userQueueCount++;
    _trimQueue();
    notifyListeners();
  }

  /// Menambahkan daftar track ke urutan "Putar Berikutnya".
  void playNextList(List<TrackModel> tracks) {
    if (tracks.isEmpty) return;
    if (_queue.isEmpty) {
      playTrack(tracks.first, queue: tracks);
      return;
    }
    final insertIndex = (_currentIndex + 1 + _userQueueCount).clamp(0, _queue.length);
    _queue.insertAll(insertIndex, tracks);
    _userQueueCount += tracks.length;
    _trimQueue();
    notifyListeners();
  }

  /// Mengaktifkan atau menonaktifkan filter SponsorBlock.
  Future<void> toggleSponsorBlock() async {
    _sponsorBlockEnabled = !_sponsorBlockEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('spotube_sponsorblock', _sponsorBlockEnabled);
    notifyListeners();
  }

  /// Mengatur keseimbangan audio kanal kiri (-1.0) hingga kanan (1.0).
  Future<void> setBalance(double value) async {
    _balance = value.clamp(-1.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('spotube_balance', _balance);
    notifyListeners();
  }

  void addToQueue(TrackModel track) {
    _queue.add(track);
    _trimQueue();
    notifyListeners();
  }

  void addTracksToQueue(List<TrackModel> tracks) {
    _queue.addAll(tracks);
    _trimQueue();
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
    _crossfadeSeconds = seconds.clamp(0, 12);
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
    } catch (e) {
      debugPrint('[Player] setPitch gagal: $e');
    }
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
    } catch (e) {
      debugPrint('[Player] setPitch gagal: $e');
    }
    notifyListeners();
  }

  // Equalizer & Bass Boost Controls
  Future<void> setEqualizerEnabled(bool enabled) async {
    _equalizerEnabled = enabled;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _equalizer.setEnabled(enabled);
      } catch (e) {
        debugPrint('[Player] equalizer toggle gagal: $e');
      }
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
        } catch (e) {
          debugPrint('[Player] equalizer preset gagal: $e');
        }
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
        } catch (e) {
          debugPrint('[Player] band gain gagal: $e');
        }
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
      } catch (e) {
        debugPrint('[Player] bass boost gagal: $e');
      }
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
    try {
      for (double vol = 1.0; vol >= 0.0; vol -= 0.2) {
        await _player.setVolume(vol.clamp(0.0, 1.0));
        await Future.delayed(const Duration(milliseconds: 600));
      }
      await pause();
    } catch (e) {
      debugPrint('[Player] sleep timer gagal: $e');
    } finally {
      await _player.setVolume(1.0);
      _sleepTimer = null;
      _sleepTimerEndTime = null;
      notifyListeners();
    }
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
      final track = _currentTrack!;
      final streamUrl = await _musicService.resolveAudioStream(
        track,
        quality: _audioQuality,
      );
      final downloadedTrack = await _downloadService.downloadTrack(
        track: track,
        audioStreamUrl: streamUrl,
        musicService: _musicService,
        quality: _audioQuality,
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
      debugPrint('[Player] unduhan gagal: $e');
      _setError('Unduhan gagal. Periksa koneksi internet lalu coba lagi.');
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
    _errorSub?.cancel();
    _becomingNoisySub?.cancel();
    _interruptionSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
