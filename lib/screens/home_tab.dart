import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final MusicService _musicService = MusicService.instance;
  List<TrackModel> _charts = [];
  bool _isLoading = true;

  final List<String> _categories = [
    'Semua',
    'Pop Indonesia',
    'Top Global',
    'Lofi Santai',
    'Rock',
    'Akustik',
    'K-Pop',
  ];
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadCategoryTracks(_selectedCategory);
  }

  Future<void> _loadCategoryTracks(String category) async {
    setState(() => _isLoading = true);
    List<TrackModel> tracks;
    if (category == 'Semua') {
      tracks = await _musicService.getChartTracks();
    } else {
      tracks = await _musicService.searchDeezer(category);
    }

    if (mounted) {
      setState(() {
        _charts = tracks;
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
    _loadCategoryTracks(category);
  }

  List<TrackModel> _getShortcutTracks(PlayerProvider player) {
    final List<TrackModel> items = [];
    for (final t in player.recentlyPlayed) {
      if (items.length >= 6) break;
      if (!items.any((existing) => existing.id == t.id)) {
        items.add(t);
      }
    }
    for (final t in _charts) {
      if (items.length >= 6) break;
      if (!items.any((existing) => existing.id == t.id)) {
        items.add(t);
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final shortcutTracks = _getShortcutTracks(player);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primaryGreen,
          backgroundColor: AppTheme.surface,
          onRefresh: () => _loadCategoryTracks(_selectedCategory),
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Wave Music',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const AppLogo(size: 44, showText: false),
                    ],
                  ),
                ),
              ),

              // Horizontal Mood / Category Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat == _selectedCategory;
                      return GestureDetector(
                        onTap: () => _onCategorySelected(cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryGreen : Colors.white12,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.black : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Spotify 6-Grid Quick Access Shortcuts
              if (shortcutTracks.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Text(
                      'Pintasan Cepat',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 2.9,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = shortcutTracks[index];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            player.playTrack(track, queue: shortcutTracks);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.card.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                                  child: CachedNetworkImage(
                                    imageUrl: track.artworkUrl,
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(color: AppTheme.surface),
                                    errorWidget: (_, _, _) => Container(
                                      color: AppTheme.surface,
                                      child: const Icon(Icons.music_note, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    track.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(Icons.play_circle_fill, color: AppTheme.primaryGreen, size: 24),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: shortcutTracks.length,
                    ),
                  ),
                ),
              ],

              // Horizontal Highlights
              if (_charts.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      'Rekomendasi Teratas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _charts.take(10).length,
                      itemBuilder: (context, index) {
                        final track = _charts[index];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            player.playTrack(track, queue: _charts);
                          },
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: track.artworkUrl,
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(
                                      color: AppTheme.card,
                                      child: const Center(child: Icon(Icons.music_note)),
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      color: AppTheme.card,
                                      child: const Center(child: Icon(Icons.music_note)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Section Title for List
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedCategory == 'Semua' ? 'Daftar Lagu Hari Ini' : 'Koleksi $_selectedCategory',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${_charts.length} lagu',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              // List of Songs or Shimmer Loading
              if (_isLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildSkeletonItem(),
                    childCount: 6,
                  ),
                )
              else if (_charts.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Tidak ada lagu yang dimuat. Tarik layar untuk menyegarkan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _charts[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: track.artworkUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(color: AppTheme.card),
                            errorWidget: (_, _, _) => Container(
                              color: AppTheme.card,
                              child: const Icon(Icons.music_note, size: 24),
                            ),
                          ),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${track.artist} • ${track.formattedDuration}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        trailing: const Icon(Icons.play_circle_fill, color: AppTheme.textSecondary, size: 22),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          player.playTrack(track, queue: _charts);
                        },
                      );
                    },
                    childCount: _charts.length,
                  ),
                ),

              // Extra bottom spacing for mini player
              const SliverToBoxAdapter(
                child: SizedBox(height: 86),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.card.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.card.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 120,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.card.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
