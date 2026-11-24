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
import '../services/audio_cache_service.dart';
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

  /// Kunci penyimpanan sesi playback terakhir (antrean + posisi).
  static const String _queueKey = 'wave_last_queue';
  static const String _queueIndexKey = 'wave_last_queue_index';
  static const String _queuePositionKey = 'wave_last_position_ms';

  /// Timer debounce agar penulisan SharedPreferences tidak terjadi setiap
  /// frame saat posisi playback berubah.
  Timer? _persistTimer;
  Duration _lastPersistedPosition = Duration.zero;

  /// True bila antrean dipulihkan dari sesi sebelumnya dan sumber audio belum
  /// dimuat. `resume()` akan memuat ulang lagu pada posisi tersimpan.
  bool _restoredSession = false;

  /// Batas jumlah lagu hasil autoplay yang ditambahkan ke antrean.
  static const int _maxAutoplayTracks = 15;

  /// Batas panjang antrean agar tidak membengkak tanpa batas.
  static const int _maxQueueLength = 300;

  /// Batas waktu menunggu sumber audio selesai dimuat.
  static const Duration _loadTimeout = Duration(seconds: 12);

  /// Batas waktu satu operasi playback (resolve + setAudioSource + seek).
  ///
  /// Tanpa batas ini, `setAudioSource` yang menggantung akan mengunci
  /// [_playChain] selamanya dan semua tap lagu berikutnya ikut antre.
  static const Duration _playOperationTimeout = Duration(seconds: 20);

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
  int _lyricsToken = 0;
  int _lyricsOffsetMs = 0;

  /// Batas usia cache lirik sebelum diambil ulang dari jaringan.
  static const Duration _lyricsCacheMaxAge = Duration(days: 30);
  static const int _lyricsCacheMaxEntries = 120;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  // Premium Features: Speed, Sleep Timer, Recently Played, Audio Quality, Autoplay
  double _playbackSpeed = 1.0;
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _sleepAtSongEnd = false;
  List<TrackModel> _recentlyPlayed = [];
  String _audioQuality = 'Otomatis (paling lancar, ~96-128 kbps)';
  bool _autoplayEnabled = true;
  bool _isFetchingAutoplay = false;
  bool _mixChartEnabled = true;

  /// Id lagu yang sudah diputar sebagai bagian radio (anti pengulangan).
  final Set<String> _radioHistory = {};

  // Crossfade
  int _crossfadeSeconds = 0;
  bool _isCrossfading = false;

  /// Token untuk membatalkan fade volume lama saat fade baru dimulai.
  int _volumeFadeToken = 0;
  bool _sleepFadeActive = false;

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

  // Dua Lapis Antrean ("Play Next" vs Context Queue).
  // Menyimpan id lagu yang dimasukkan lewat "Putar Berikutnya" agar jumlahnya
  // bisa dihitung ulang setelah reorder/remove/trim, bukan sekadar counter
  // yang mudah melenceng.
  final Set<String> _userQueueIds = <String>{};

  // Serialisasi playback & penanganan error.
  Future<void> _playChain = Future<void>.value();
  int _playToken = 0;
  String? _errorMessage;
  bool _disposed = false;

  /// Id lagu yang sudah dicoba ulang dengan stream MP4/AAC.
  ///
  /// Sebagian perangkat lama gagal mendekode Opus/WebM. Untuk lagu yang
  /// bermasalah, pemutaran dicoba sekali lagi memakai kontainer MP4 (AAC).
  String? _mp4FallbackTrackId;

  /// Sumber proxy aktif. Harus ditutup saat lagu berganti agar socket tidak
  /// menumpuk.
  YouTubeStreamSource? _activeStreamSource;

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
        androidAudioEffects: (!kIsWeb && Platform.isAndroid)
            ? [_equalizer, _loudnessEnhancer]
            : const [],
      ),
    );
    _initPlayer();
    _initAudioSession();
    _bootstrap();
  }

  /// Memuat preferensi terlebih dahulu, baru menerapkan equalizer.
  ///
  /// Sebelumnya `_initEqualizer` dan `_loadPreferences` berjalan bersamaan,
  /// sehingga preset yang tersimpan bisa tertimpa nilai default.
  Future<void> _bootstrap() async {
    await _loadPreferences();
    await _initEqualizer();
    await _loadRecentlyPlayed();
    await _restorePlaybackState();
    // Terapkan efek yang tersimpan ke player yang baru dibuat. Tanpa ini,
    // kecepatan/pitch/loop kembali ke default setiap aplikasi dibuka.
    try {
      await _player.setSpeed(_playbackSpeed);
      await _player.setPitch(_pitch);
      await _player.setLoopMode(_loopMode);
    } catch (e) {
      debugPrint('[Player] gagal menerapkan efek tersimpan: $e');
    }
    notifyListeners();
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

  /// Offset sinkronisasi lirik dalam milidetik (positif = lirik lebih cepat).
  int get lyricsOffsetMs => _lyricsOffsetMs;
  Duration get lyricsOffset => Duration(milliseconds: _lyricsOffsetMs);
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  /// True bila antrean terakhir dipulihkan dan audio belum dimuat.
  bool get hasRestoredSession => _restoredSession;

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

  /// Jumlah lagu "Putar Berikutnya" yang masih berada setelah lagu aktif.
  ///
  /// Bila belum ada lagu yang diputar, seluruh lagu bertanda "Putar Berikutnya"
  /// dihitung karena semuanya masih akan diputar.
  int get userQueueCount {
    var count = 0;
    final start = _currentIndex < 0 ? 0 : _currentIndex + 1;
    for (var i = start; i < _queue.length; i++) {
      if (_userQueueIds.contains(_queue[i].id)) count++;
    }
    return count;
  }

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
    if (token != _playToken || !_isLoadingAudio) return;

    // Jangan bergantung pada `_position == Duration.zero`: saat resume dari
    // posisi tengah lagu, posisi tidak pernah nol sehingga timeout tidak pernah
    // terpicu. `_isLoadingAudio` adalah penanda yang tepat.
    _isLoadingAudio = false;
    // Batalkan rantai pemuatan yang masih berjalan agar tidak menimpa error
    // dengan sumber audio yang datang terlambat.
    _playToken++;
    _setError(
      'Lagu "${track.title}" tidak dapat dimuat. Periksa koneksi lalu coba lagi.',
    );
  }

  void _initPlayer() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;

      if (state.processingState == ProcessingState.completed) {
        // Abaikan sinyal completed palsu (mis. bug just_audio_windows di detik 0 saat loading sumber audio)
        final effectiveDuration = _duration > Duration.zero
            ? _duration
            : (_currentTrack != null
                ? Duration(milliseconds: _currentTrack!.durationMs)
                : Duration.zero);

        final isRealEnd = !_isLoadingAudio &&
            (_position > const Duration(seconds: 2) ||
                (effectiveDuration > Duration.zero &&
                    _position >= effectiveDuration - const Duration(seconds: 3)));

        if (isRealEnd) {
          if (_sleepAtSongEnd) {
            pause();
            _sleepAtSongEnd = false;
            notifyListeners();
          } else {
            next();
          }
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
      // Player yang masih idle (belum ada sumber audio) bisa memancarkan
      // posisi 0. Jangan biarkan itu menimpa posisi sesi yang dipulihkan.
      if (_restoredSession && _player.audioSource == null) return;
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
      // Simpan posisi secara berkala (bukan tiap frame) agar sesi bisa
      // dilanjutkan setelah aplikasi ditutup paksa.
      if ((pos - _lastPersistedPosition).abs() >= const Duration(seconds: 5)) {
        _lastPersistedPosition = pos;
        _schedulePersistPlaybackState();
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
        await _loudnessEnhancer.setTargetGain(_bassBoostGain * 1000.0);
        if (_equalizerEnabled) {
          await _applyEqualizerGains();
        }
      } catch (e) {
        debugPrint('[Player] equalizer init gagal: $e');
      }
    }
  }

  Future<void> _applyEqualizerGains() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final params = await _equalizer.parameters;
      for (int i = 0; i < params.bands.length && i < _customBandGains.length; i++) {
        await params.bands[i].setGain(_customBandGains[i]);
      }
    } catch (e) {
      debugPrint('[Player] penerapan gain equalizer gagal: $e');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sponsorBlockEnabled =
          prefs.getBool('spotube_sponsorblock') ?? _sponsorBlockEnabled;
      _balance = (prefs.getDouble('spotube_balance') ?? _balance).clamp(-1.0, 1.0);
      final storedQuality = prefs.getString('spotube_audio_quality');
      if (storedQuality != null) {
        // Migrasi label lama yang menjanjikan 320 kbps (tidak pernah tercapai
        // karena stream YouTube maksimal sekitar 160 kbps).
        _audioQuality = storedQuality.toLowerCase().contains('maksimal')
            ? 'Otomatis (paling lancar, ~96-128 kbps)'
            : storedQuality;
      }
      _isShuffle = prefs.getBool('spotube_shuffle') ?? _isShuffle;
      final loopName = prefs.getString('spotube_loop_mode');
      if (loopName != null) {
        _loopMode = LoopMode.values.firstWhere(
          (mode) => mode.name == loopName,
          orElse: () => _loopMode,
        );
      }
      _crossfadeSeconds =
          (prefs.getInt('spotube_crossfade_seconds') ?? _crossfadeSeconds)
              .clamp(0, 12);
      _playbackSpeed =
          (prefs.getDouble('spotube_playback_speed') ?? _playbackSpeed)
              .clamp(0.5, 2.0);
      _pitchSemitones =
          (prefs.getInt('spotube_pitch_semitones') ?? _pitchSemitones)
              .clamp(-6, 6);
      _pitch = math.pow(2.0, _pitchSemitones / 12.0).toDouble();
      _audioPreset = prefs.getString('spotube_audio_preset') ?? _audioPreset;
      _equalizerEnabled =
          prefs.getBool('spotube_equalizer_enabled') ?? _equalizerEnabled;
      _equalizerPreset =
          prefs.getString('spotube_equalizer_preset') ?? _equalizerPreset;
      _bassBoostGain =
          (prefs.getDouble('spotube_bass_boost') ?? _bassBoostGain)
              .clamp(0.0, 1.0);

      final rawGains = prefs.getString('spotube_band_gains');
      if (rawGains != null) {
        final decoded = jsonDecode(rawGains);
        if (decoded is List) {
          final gains =
              decoded.whereType<num>().map((e) => e.toDouble()).toList();
          if (gains.length == _customBandGains.length) {
            _customBandGains = gains;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Player] gagal memuat preferensi: $e');
    }
  }

  Future<void> _savePref(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('[Player] gagal menyimpan preferensi $key: $e');
    }
  }

  void _checkSponsorSegments(Duration pos) {
    if (_lastSkippedUntil != null && pos < _lastSkippedUntil!) {
      return;
    }
    for (final seg in _activeSegments) {
      if (!seg.shouldAutoSkip) continue;
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

  /// Memudarkan volume dari nilai saat ini menuju [target].
  ///
  /// Setiap pemanggilan menaikkan [_volumeFadeToken] sehingga fade yang lebih
  /// baru otomatis membatalkan fade lama. Ini mencegah crossfade dan sleep
  /// timer saling menimpa volume.
  Future<void> _fadeVolumeTo(double target, Duration stepDuration) async {
    final token = ++_volumeFadeToken;
    final start = _player.volume.clamp(0.0, 1.0);
    final steps = ((start - target).abs() / 0.2).ceil().clamp(1, 10);
    for (var i = 0; i <= steps; i++) {
      if (token != _volumeFadeToken) return;
      final value = start + (target - start) * (i / steps);
      await _player.setVolume(value.clamp(0.0, 1.0));
      if (i < steps) {
        await Future.delayed(stepDuration);
      }
    }
  }

  Future<void> _triggerCrossfade() async {
    if (_isCrossfading || _sleepFadeActive) return;
    _isCrossfading = true;
    try {
      final stepDuration =
          Duration(milliseconds: (_crossfadeSeconds * 1000 ~/ 5).clamp(100, 1000));
      await _fadeVolumeTo(0.1, stepDuration);
      if (_sleepFadeActive) return;
      if (_loopMode == LoopMode.one && _currentTrack != null) {
        // Repeat-one: ulangi lagu yang sama tanpa memuat ulang stream.
        await _player.seek(Duration.zero);
        await _player.play();
      } else {
        await next();
      }
      if (_sleepFadeActive) return;
      await _fadeVolumeTo(1.0, const Duration(milliseconds: 200));
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

  /// Menjadwalkan penyimpanan sesi playback dengan debounce singkat.
  void _schedulePersistPlaybackState() {
    _persistTimer?.cancel();
    _persistTimer = Timer(
      const Duration(milliseconds: 800),
      () => unawaited(_persistPlaybackState()),
    );
  }

  /// Menyimpan antrean, indeks, dan posisi lagu agar bisa dilanjutkan lagi.
  ///
  /// Antrean dibatasi 100 lagu di sekitar lagu aktif supaya ukuran
  /// SharedPreferences tetap wajar meski antrean mencapai ratusan lagu.
  Future<void> _persistPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_queue.isEmpty || _currentTrack == null || _currentIndex < 0) {
        await prefs.remove(_queueKey);
        await prefs.remove(_queueIndexKey);
        await prefs.remove(_queuePositionKey);
        return;
      }

      final start = math.max(0, _currentIndex - 50);
      final end = math.min(_queue.length, start + 100);
      final slice = _queue.sublist(start, end);
      await prefs.setStringList(
        _queueKey,
        slice.map((track) => track.toJson()).toList(),
      );
      await prefs.setInt(_queueIndexKey, _currentIndex - start);
      await prefs.setInt(_queuePositionKey, _position.inMilliseconds);
    } catch (e) {
      debugPrint('[Player] gagal menyimpan sesi playback: $e');
    }
  }

  /// Memulihkan antrean terakhir tanpa langsung memutar audio.
  Future<void> _restorePlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey);
      if (raw == null || raw.isEmpty) return;

      final restored = <TrackModel>[];
      for (final item in raw) {
        try {
          restored.add(TrackModel.fromJson(item));
        } catch (e) {
          debugPrint('[Player] entri antrean tersimpan rusak dilewati: $e');
        }
      }
      if (restored.isEmpty) return;

      var index = prefs.getInt(_queueIndexKey) ?? 0;
      if (index < 0 || index >= restored.length) index = 0;

      final track = restored[index];
      final savedMs = prefs.getInt(_queuePositionKey) ?? 0;
      final maxMs = track.durationMs > 0 ? track.durationMs : savedMs;
      _queue = restored;
      _currentIndex = index;
      _currentTrack = track;
      _position = Duration(milliseconds: savedMs.clamp(0, maxMs));
      _duration = Duration(milliseconds: track.durationMs);
      _isPlaying = false;
      _restoredSession = true;
      debugPrint(
        '[Player] sesi dipulihkan: "${track.title}" @ ${_position.inSeconds}s',
      );
    } catch (e) {
      debugPrint('[Player] gagal memulihkan sesi playback: $e');
    }
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
        ).timeout(
          _playOperationTimeout,
          onTimeout: () {
            // Batalkan request yang menggantung agar rantai playback tidak
            // terkunci selamanya. Token dinaikkan supaya kelanjutan async
            // milik request lama tidak lagi menyentuh state pemutar.
            if (token == _playToken) {
              _playToken++;
              _isLoadingAudio = false;
              _setError(
                'Pemuatan "${track.title}" melewati batas waktu. Coba lagi.',
              );
              unawaited(_player.stop());
            }
            throw TimeoutException(
              'Pemuatan audio melewati ${_playOperationTimeout.inSeconds} detik.',
            );
          },
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
    _restoredSession = false;
    _schedulePersistPlaybackState();

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
    // Lagu yang berasal dari "Putar Berikutnya" sudah mulai diputar, jadi
    // keluarkan id-nya dari penanda antrean pengguna.
    _userQueueIds.remove(track.id);
    _loadSponsorSegments(track);

    // Jangan menyentuh sumber audio bila request ini sudah dibatalkan
    // (mis. timeout atau pengguna memilih lagu lain saat resolve berjalan).
    if (token != _playToken) return;

    try {
      final mediaItem = MediaItem(
        id: track.id,
        album: track.album.isNotEmpty ? track.album : 'Single',
        title: track.title,
        artist: track.artist,
        artUri: track.artworkUrl.isNotEmpty ? Uri.tryParse(track.artworkUrl) : null,
        duration: Duration(milliseconds: track.durationMs),
      );

      // Tutup proxy lagu sebelumnya sebelum mengganti sumber audio.
      _activeStreamSource?.close();
      _activeStreamSource = null;

      final isLocal =
          track.localPath != null && await File(track.localPath!).exists();

      File? cachedFile;
      if (!isLocal) {
        cachedFile = await AudioCacheService.instance
            .getCachedAudioFile(track.id, quality: _audioQuality);
      }

      if (isLocal) {
        await _player.setAudioSource(
          AudioSource.file(track.localPath!, tag: mediaItem),
        );
      } else if (cachedFile != null) {
        debugPrint('[Player] Memutar dari smart LRU cache: ${track.title}');
        await _player.setAudioSource(
          AudioSource.file(cachedFile.path, tag: mediaItem),
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
          preferProgressive: _shouldPreferProgressive(_queue[_currentIndex + 1]),
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
  /// Apakah stream progressive muxed (tag 18) dipakai.
  ///
  /// Hanya untuk mode "Otomatis" dan fallback MP4. Mode kualitas lain memakai
  /// stream audio-only agar pilihan 64/128/160 kbps benar-benar diterapkan.
  bool _shouldPreferProgressive(TrackModel track) {
    return _mp4FallbackTrackId == track.id ||
        _audioQuality.toLowerCase().contains('otomatis');
  }

  Future<void> _setStreamSource(
    TrackModel track,
    MediaItem mediaItem, {
    bool forceRefresh = false,
  }) async {
    final preferProgressive = _shouldPreferProgressive(track);
    final resolved = await _musicService.resolveAudioStreamInfo(
      track,
      quality: _audioQuality,
      forceRefresh: forceRefresh,
      preferredContainer: _preferredContainerFor(track),
      preferProgressive: preferProgressive,
    );

    if (resolved.isDirectProgressive) {
      unawaited(AudioCacheService.instance.cacheTrackFromUrl(
        track.id,
        resolved.url,
        quality: _audioQuality,
      ));
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
        preferProgressive: preferProgressive,
        tag: mediaItem,
      );
      _activeStreamSource = source;
      await _player.setAudioSource(source);
    }
  }

  Future<void> _fetchLyrics(TrackModel track) async {
    final requestToken = ++_lyricsToken;
    _isLoadingLyrics = true;
    _lyrics = [];
    _lyricsOffsetMs = 0;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final savedOffset = (prefs.getInt('wave_lyrics_offset_${track.id}') ?? 0)
        .clamp(-5000, 5000)
        .toInt();

    // Bila lagu sudah berganti saat preferensi dibaca, jangan menimpa offset
    // lagu yang baru dengan nilai lagu lama.
    if (requestToken != _lyricsToken) return;
    _lyricsOffsetMs = savedOffset;
    notifyListeners();

    List<LyricsLine> result = [];
    try {
      result = await _readCachedLyrics(prefs, track.id);
      if (result.isEmpty) {
        if (requestToken != _lyricsToken) return;
        result = await _lyricsService.fetchLyrics(
          title: track.title,
          artist: track.artist,
        );
        if (result.isNotEmpty) {
          await _writeCachedLyrics(prefs, track.id, result);
        }
      }
    } catch (e) {
      debugPrint('[Player] lirik gagal dimuat: $e');
    }

    // Respons lambat dari lagu lama tidak boleh menimpa lirik lagu baru.
    if (requestToken != _lyricsToken || _currentTrack?.id != track.id) {
      return;
    }

    _lyrics = result;
    _isLoadingLyrics = false;
    notifyListeners();
  }

  /// Membaca lirik dari cache lokal bila masih segar.
  Future<List<LyricsLine>> _readCachedLyrics(
    SharedPreferences prefs,
    String trackId,
  ) async {
    try {
      final raw = prefs.getString('wave_lyrics_cache_$trackId');
      if (raw == null) return const [];
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = (decoded['savedAt'] as num?)?.toInt() ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      if (age < 0 || age > _lyricsCacheMaxAge.inMilliseconds) {
        return const [];
      }
      final lines = (decoded['lines'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(LyricsLine.fromMap)
          .toList();
      return lines;
    } catch (e) {
      debugPrint('[Player] cache lirik rusak dilewati: $e');
      return const [];
    }
  }

  /// Menyimpan lirik ke cache lokal dan membatasi jumlah entri.
  Future<void> _writeCachedLyrics(
    SharedPreferences prefs,
    String trackId,
    List<LyricsLine> lines,
  ) async {
    try {
      await prefs.setString(
        'wave_lyrics_cache_$trackId',
        jsonEncode({
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'lines': lines.map((line) => line.toMap()).toList(),
        }),
      );
      await _pruneLyricsCache(prefs);
    } catch (e) {
      debugPrint('[Player] gagal menyimpan cache lirik: $e');
    }
  }

  Future<void> _pruneLyricsCache(SharedPreferences prefs) async {
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('wave_lyrics_cache_'))
        .toList();
    if (keys.length <= _lyricsCacheMaxEntries) return;

    final entries = <({String key, int savedAt})>[];
    for (final key in keys) {
      try {
        final decoded =
            jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
        entries.add((
          key: key,
          savedAt: (decoded['savedAt'] as num?)?.toInt() ?? 0,
        ));
      } catch (_) {
        entries.add((key: key, savedAt: 0));
      }
    }
    entries.sort((a, b) => a.savedAt.compareTo(b.savedAt));
    final excess = entries.length - _lyricsCacheMaxEntries;
    for (var i = 0; i < excess; i++) {
      await prefs.remove(entries[i].key);
    }
  }

  /// Menggeser sinkronisasi lirik sebesar [deltaMs] milidetik.
  Future<void> setLyricsOffset(int deltaMs) async {
    final track = _currentTrack;
    _lyricsOffsetMs = (_lyricsOffsetMs + deltaMs).clamp(-5000, 5000).toInt();
    notifyListeners();
    if (track == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('wave_lyrics_offset_${track.id}', _lyricsOffsetMs);
    } catch (e) {
      debugPrint('[Player] gagal menyimpan offset lirik: $e');
    }
  }

  Future<void> resetLyricsOffset() async {
    final track = _currentTrack;
    _lyricsOffsetMs = 0;
    notifyListeners();
    if (track == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wave_lyrics_offset_${track.id}');
    } catch (e) {
      debugPrint('[Player] gagal mereset offset lirik: $e');
    }
  }

  /// Posisi seek yang tepat untuk baris lirik dengan [timestamp].
  Duration lyricSeekPosition(Duration timestamp) {
    final target = timestamp - lyricsOffset;
    return target < Duration.zero ? Duration.zero : target;
  }

  int get currentLyricsIndex {
    if (_lyrics.isEmpty) return -1;
    final effectivePosition = _position + lyricsOffset;
    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (effectivePosition >= _lyrics[i].timestamp) {
        return i;
      }
    }
    return 0;
  }

  Future<void> resume() async {
    // Sesi yang dipulihkan belum punya sumber audio. Muat ulang lagu pada
    // posisi terakhir, bukan memanggil play() pada player kosong.
    if (_player.audioSource == null && _currentTrack != null) {
      final track = _currentTrack!;
      final resumePosition = _position;
      _restoredSession = false;
      await playTrack(
        track,
        queue: _queue,
        explicitIndex: _currentIndex >= 0 ? _currentIndex : null,
        initialPosition: resumePosition,
      );
      return;
    }
    _restoredSession = false;
    await _player.play();
    _schedulePersistPlaybackState();
  }

  Future<void> pause() async {
    await _player.pause();
    _schedulePersistPlaybackState();
  }

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
    // Sebelum sumber audio dimuat (sesi dipulihkan), cukup perbarui posisi
    // yang akan dipakai saat tombol putar ditekan.
    if (_player.audioSource == null) {
      _position = pos;
      _schedulePersistPlaybackState();
      notifyListeners();
      return;
    }
    await _player.seek(pos);
    _schedulePersistPlaybackState();
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

    // Buang dari ekor antrean (lagu paling jauh) dan lindungi lagu yang
    // dimasukkan lewat "Putar Berikutnya". Dengan begitu lagu yang baru
    // disisipkan setelah lagu aktif tidak langsung terhapus.
    for (int i = _queue.length - 1; i >= 0 && removable.length < excess; i--) {
      if (i == _currentIndex) continue;
      if (_userQueueIds.contains(_queue[i].id)) continue;
      removable.add(i);
    }
    // Bila masih kurang (mis. semua sisa lagu adalah "Putar Berikutnya"),
    // buang sisanya kecuali lagu yang sedang diputar.
    if (removable.length < excess) {
      for (int i = _queue.length - 1; i >= 0 && removable.length < excess; i--) {
        if (i == _currentIndex || removable.contains(i)) continue;
        removable.add(i);
      }
    }
    // removable tersusun dari indeks terbesar ke terkecil, sehingga aman
    // dihapus berurutan tanpa menggeser indeks yang belum diproses.
    for (final index in removable) {
      _queue.removeAt(index);
    }
    // Buang penanda "Putar Berikutnya" untuk lagu yang sudah tidak ada.
    _userQueueIds.removeWhere((id) => !_queue.any((t) => t.id == id));
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
    unawaited(_savePref('spotube_shuffle', _isShuffle));
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
    unawaited(_savePref('spotube_loop_mode', _loopMode.name));
    notifyListeners();
  }

  /// Posisi sisip untuk "Putar Berikutnya": tepat setelah lagu aktif dan
  /// setelah lagu-lagu "Putar Berikutnya" yang sudah lebih dulu masuk.
  ///
  /// Saat belum ada lagu aktif, seluruh lagu "Putar Berikutnya" berada di awal
  /// antrean sehingga sisipan baru diletakkan setelahnya.
  int get _playNextInsertIndex {
    final base = _currentIndex < 0 ? 0 : _currentIndex + 1;
    return (base + userQueueCount).clamp(0, _queue.length);
  }

  /// Memutar track ini persis setelah lagu yang sedang aktif selesai ("Play Next").
  void playNext(TrackModel track) {
    if (_queue.isEmpty) {
      playTrack(track, queue: [track]);
      return;
    }
    _queue.insert(_playNextInsertIndex, track);
    _userQueueIds.add(track.id);
    _trimQueue();
    _schedulePersistPlaybackState();
    notifyListeners();
  }

  /// Menambahkan daftar track ke urutan "Putar Berikutnya".
  void playNextList(List<TrackModel> tracks) {
    if (tracks.isEmpty) return;
    if (_queue.isEmpty) {
      playTrack(tracks.first, queue: tracks);
      return;
    }
    _queue.insertAll(_playNextInsertIndex, tracks);
    _userQueueIds.addAll(tracks.map((t) => t.id));
    _trimQueue();
    _schedulePersistPlaybackState();
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
    _schedulePersistPlaybackState();
    notifyListeners();
  }

  void addTracksToQueue(List<TrackModel> tracks) {
    _queue.addAll(tracks);
    _trimQueue();
    _schedulePersistPlaybackState();
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
    _schedulePersistPlaybackState();
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;

    final removed = _queue.removeAt(index);
    _userQueueIds.remove(removed.id);

    if (removed.id == _currentTrack?.id) {
      // Lagu yang sedang diputar ikut dihapus: hentikan dan lanjutkan ke lagu
      // terdekat yang masih tersisa, bukan meninggalkan _currentIndex = -1.
      _currentTrack = null;
      _currentIndex = -1;
      if (_queue.isEmpty) {
        unawaited(_player.stop());
      } else {
        final nextIndex = index.clamp(0, _queue.length - 1);
        unawaited(playTrack(
          _queue[nextIndex],
          queue: _queue,
          explicitIndex: nextIndex,
        ));
      }
    } else if (index < _currentIndex) {
      _currentIndex--;
    }

    _schedulePersistPlaybackState();
    notifyListeners();
  }

  void clearQueue() {
    _userQueueIds.clear();
    if (_currentTrack != null) {
      _queue = [_currentTrack!];
      _currentIndex = 0;
    } else {
      _queue.clear();
      _currentIndex = -1;
    }
    _schedulePersistPlaybackState();
    notifyListeners();
  }

  // Crossfade Control
  void setCrossfadeSeconds(int seconds) {
    _crossfadeSeconds = seconds.clamp(0, 12);
    unawaited(_savePref('spotube_crossfade_seconds', _crossfadeSeconds));
    notifyListeners();
  }

  // Speed Control
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.5, 2.0);
    await _player.setSpeed(_playbackSpeed);
    await _savePref('spotube_playback_speed', _playbackSpeed);
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
    await _savePref('spotube_pitch_semitones', _pitchSemitones);
    await _savePref('spotube_audio_preset', _audioPreset);
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
    await _savePref('spotube_playback_speed', _playbackSpeed);
    await _savePref('spotube_pitch_semitones', _pitchSemitones);
    await _savePref('spotube_audio_preset', _audioPreset);
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
    await _savePref('spotube_equalizer_enabled', _equalizerEnabled);
    notifyListeners();
  }

  Future<void> setEqualizerPreset(String preset) async {
    _equalizerPreset = preset;
    final gains = equalizerPresets[preset];
    if (gains != null) {
      _customBandGains = List.from(gains);
      await _applyEqualizerGains();
    }
    await _savePref('spotube_equalizer_preset', _equalizerPreset);
    await _savePref('spotube_band_gains', jsonEncode(_customBandGains));
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
      await _savePref('spotube_equalizer_preset', _equalizerPreset);
      await _savePref('spotube_band_gains', jsonEncode(_customBandGains));
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
    await _savePref('spotube_bass_boost', _bassBoostGain);
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
    _sleepFadeActive = true;
    // Batalkan fade crossfade yang mungkin sedang berjalan agar tidak
    // menaikkan volume lagi setelah sleep fade selesai.
    _volumeFadeToken++;
    try {
      await _fadeVolumeTo(0.0, const Duration(milliseconds: 600));
      await pause();
    } catch (e) {
      debugPrint('[Player] sleep timer gagal: $e');
    } finally {
      await _player.setVolume(1.0);
      _sleepFadeActive = false;
      _sleepTimer = null;
      _sleepTimerEndTime = null;
      notifyListeners();
    }
  }

  Future<void> setAudioQuality(String quality) async {
    if (_audioQuality == quality) return;
    _audioQuality = quality;
    await _savePref('spotube_audio_quality', _audioQuality);
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
  void notifyListeners() {
    // Respons jaringan (lirik, SponsorBlock, unduhan) bisa selesai setelah
    // provider dibuang. Jangan panggil ChangeNotifier yang sudah di-dispose.
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sleepTimer?.cancel();
    _persistTimer?.cancel();
    unawaited(_persistPlaybackState());
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _errorSub?.cancel();
    _becomingNoisySub?.cancel();
    _interruptionSub?.cancel();
    _activeStreamSource?.close();
    _player.dispose();
    super.dispose();
  }
}
