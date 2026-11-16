# PROJECT STATE

## Overview
- Project Name: Wave Music (`spotify_pribadi`)
- Architecture: Standalone client-side music player (Zero-login, No-Firebase, 100% local persistence)
- Catalog & Streaming: Deezer API (metadata/cover art) + YouTube audio streams via direct chunked `Range` requests (`YouTubeStreamSource`)
- State Management: Provider (`PlayerProvider`, `LibraryProvider`)

## Critical Architecture Decisions
1. **Streaming Stability & Mid-Track Resiliency**: `YouTubeStreamSource` uses `fetchRangeResilient` to fetch arbitrary byte slices directly without downloading sequential 0-to-target dummy chunks. If YouTube CDN drops a session or returns 403 mid-track, the URL automatically refreshes and continues from the exact byte offset seamlessly.
2. **Playback Position Continuity**: `PlayerProvider` preserves the current playback position during error recovery and retries, eliminating mid-song resets to 0:00.
3. **Local Persistence**: All user data (Liked Songs, Custom Playlists, Recently Played) are stored locally via `LocalLibraryService` using `SharedPreferences`. No external cloud or database dependencies.
4. **Audio Export & Tagging**: Audio files are saved with native formats detected by header magic bytes (`AudioFormat.detect`). MP3 files receive ID3v2.3 tags (`Id3Writer`).
5. **Storage Permissions**: Android 11+ scoped storage / `MANAGE_EXTERNAL_STORAGE` bridged through `StoragePermissionService` MethodChannel (`com.david.spotify_pribadi/storage`).
6. **Android 13+ Media Notifications**: Declared `android.permission.POST_NOTIFICATIONS` in `AndroidManifest.xml` to ensure media controls render on modern Android lockscreens and notification bars.
7. **Audio Session & Becoming Noisy**: Listened to `session.becomingNoisyEventStream` and `session.interruptionEventStream` in `PlayerProvider` to pause on headset/Bluetooth disconnection and restore gracefully on call completion.
8. **In-App Version Checker & Battery Guide**: Added `UpdateService` querying `version.json` directly from GitLab repository and intent launcher for Android battery optimization (Doze mode) settings.
9. **SponsorBlock Integration**: Integrated `SponsorBlockService` querying `sponsor.ajay.app` for active YouTube track to automatically skip skit, offtopic dialogue, non-music sections, intro, and outro.
10. **Two-Tier Priority Queue ("Play Next")**: Implemented user-priority queue (`playNext`) inserting tracks right after currently playing item before resuming background playlist context.
11. **Universal Playlist Backup**: Implemented `PlaylistBackupService` for two-way export and restore via JSON and standard M3U (#EXTM3U) formats.
12. **Stereo Audio Balance**: Implemented Left/Right balance control (-1.0 to 1.0) with persistence.

## Verification Status
- Version: 1.0.2 (Build 3)
- Static Analysis: `flutter analyze` passed (0 issues).
- Unit Tests: `flutter test` passed (57/57 tests passing).
- Build: Release split-per-ABI APKs generated in `apk/`.
