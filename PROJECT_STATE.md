# PROJECT STATE

## Overview
- Project Name: Wave Music (`spotify_pribadi`)
- Architecture: Standalone client-side music player (Zero-login, No-Firebase, 100% local persistence)
- Catalog & Streaming: Hybrid Engine (Deezer API + YouTube parallel search with relevance ranking) + Direct Progressive (`tag 18` and muxed MP4 AAC stereo with `ratebypass=yes`) and resilient auto-recovery
- State Management: Provider (`PlayerProvider`, `LibraryProvider`)

## Critical Architecture Decisions
1. **Hybrid Search Engine & Metadata Hygiene**: `MusicService.searchMusic` queries Deezer and YouTube in parallel. Cleans titles (`cleanTitle`/`parseYouTubeMetadata`) removing amateur tags `[Official Video]`, `(Lyrics)`, etc. Filters out karaoke, lyric-only channels, and long compilations (>15 min). Scores and sorts tracks by relevance so official artist tracks rank first.
2. **Instant Playback & Mid-Song 403 Elimination**: `MusicService.resolveAudioStreamInfo` fetches YouTube manifests with `requireWatchPage: false` (reducing latency to ~350ms) and resolves progressive streams (`tag 18` or lowest-bitrate muxed MP4). `PlayerProvider._setStreamSource` feeds direct progressive streams straight to ExoPlayer via `AudioSource.uri(url, headers: ...)`, eliminating the local HTTP proxy burst limits (512 KB–1 MB) and stopping mid-track 403 buffer drops and infinite song restarts.
3. **Bulletproof Recovery & Position Preservation**: If network hiccups occur mid-track, `_scheduleMp4Fallback` forces a fresh signed URL (`forceStreamRefresh: true`) while retaining progressive stream priority and seeking directly to `resumePosition`. Retry attempts are capped at 2 per track to prevent infinite restart loops.
4. **Explicit Index Queue Navigation**: `PlayerProvider` uses `explicitIndex` for `playTrack`, `next()`, `previous()`, and `QueueSheet` tapping. Eliminates snap-back loops to earlier duplicate tracks in the search queue.
5. **Non-Blocking Asynchronous Local Audio Scanner**: `LocalAudioService.scanLocalAudioFiles` operates asynchronously via `dir.list(recursive: true)` stream, eliminating main-thread UI freezes and Android ANR prompts during deep storage scans.
6. **Offline Resilient Screens**: `home_tab.dart` and `search_tab.dart` isolate network operations in `try-catch-finally` blocks, transitioning smoothly to empty/offline states without indefinite loading spinners.
7. **Safe Lyric Query Sanitizer**: `LyricsService.sanitizeQueryTitle` cleans metadata brackets while safely preserving legitimate hyphenated words (e.g. "Spider-Man", "Anti-Hero", "Semi-Charmed Life").
8. **Bounded In-Memory Caching**: `MusicService._videoIdCache`, `_streamUrlCache`, and `SponsorBlockService._cache` are capped at 200 entries with automatic oldest-entry eviction.
9. **High-Speed Offline Downloads**: `DownloadService` utilizes 256 KB chunking with progressive stream resolution, completing offline downloads in 1-2 seconds without 1 MB DASH stalling.
10. **Responsive Audio Watchdog**: Audio loading timeout set to 12 seconds (`_loadTimeout`), providing fast feedback if network is unavailable.
11. **Pre-caching Next Track**: `PlayerProvider` initiates background stream pre-fetching (`preloadTrackStream`) for `_queue[_currentIndex + 1]` upon playback start for near-zero latency track transitions.
12. **Diversified Track Radio**: `getRadioTracks` mixes artist-specific tracks with global chart tracks and caps each artist to a maximum of 2 songs, preventing homogeneous track flooding.
13. **Local Persistence**: All user data (Liked Songs, Custom Playlists, Recently Played) are stored locally via `LocalLibraryService` using `SharedPreferences`. No external cloud or database dependencies.
14. **Audio Export & Tagging**: Audio files are saved with native formats detected by header magic bytes (`AudioFormat.detect`). MP3 files receive ID3v2.3 tags (`Id3Writer`).
15. **Storage Permissions**: Android 11+ scoped storage / `MANAGE_EXTERNAL_STORAGE` bridged through `StoragePermissionService` MethodChannel (`com.david.spotify_pribadi/storage`).
16. **Android 13+ Media Notifications**: Declared `android.permission.POST_NOTIFICATIONS` in `AndroidManifest.xml` to ensure media controls render on modern Android lockscreens and notification bars.
17. **Audio Session & Becoming Noisy**: Listened to `session.becomingNoisyEventStream` and `session.interruptionEventStream` in `PlayerProvider` to pause on headset/Bluetooth disconnection and restore gracefully on call completion.
18. **In-App Version Checker & Battery Guide**: Added `UpdateService` querying `version.json` directly from GitLab repository and intent launcher for Android battery optimization (Doze mode) settings.
19. **SponsorBlock Integration**: Integrated `SponsorBlockService` querying `sponsor.ajay.app` for active YouTube track to automatically skip skit, offtopic dialogue, non-music sections, intro, and outro.
20. **Two-Tier Priority Queue ("Play Next")**: Implemented user-priority queue (`playNext`) inserting tracks right after currently playing item before resuming background playlist context.
21. **Universal Playlist Backup**: Implemented `PlaylistBackupService` for two-way export and restore via JSON and standard M3U (#EXTM3U) formats.
22. **Stereo Audio Balance**: Implemented Left/Right balance control (-1.0 to 1.0) with persistence.

## Verification Status
- Version: 1.0.3 (Build 4)
- Static Analysis: `flutter analyze` passed (0 issues).
- Unit Tests: `flutter test` passed (66/66 tests passing).
- Build: Release split-per-ABI APKs generated in `apk/`.
