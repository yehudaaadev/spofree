import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track_model.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../theme/app_theme.dart';

class _GenreCardData {
  final String title;
  final String query;
  final List<Color> colors;
  final IconData icon;

  const _GenreCardData(this.title, this.query, this.colors, this.icon);
}

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final MusicService _musicService = MusicService.instance;
  Timer? _debounce;
  List<TrackModel> _results = [];
  bool _isLoading = false;
  String _currentQuery = '';
  List<String> _recentSearches = [];

  static const List<_GenreCardData> _genres = [
    _GenreCardData('Pop Indo', 'Pop Indonesia', [Color(0xFFE1306C), Color(0xFF833AB4)], Icons.music_note),
    _GenreCardData('Top Global', 'Top Hits Global', [Color(0xFF1DB954), Color(0xFF191414)], Icons.public),
    _GenreCardData('Lofi & Santai', 'Lofi Chill Beats', [Color(0xFF4A00E0), Color(0xFF8E2DE2)], Icons.nightlight_round),
    _GenreCardData('Rock Klasik', 'Rock', [Color(0xFFE52D27), Color(0xFFB31217)], Icons.electric_bolt),
    _GenreCardData('Hip Hop & RnB', 'Hip Hop R&B', [Color(0xFFF7971E), Color(0xFFFFD200)], Icons.speaker_group),
    _GenreCardData('Akustik', 'Akustik Santai', [Color(0xFF11998E), Color(0xFF38EF7D)], Icons.queue_music),
    _GenreCardData('K-Pop Hits', 'K-Pop', [Color(0xFFFF5F6D), Color(0xFFFFC371)], Icons.star),
    _GenreCardData('Focus & Studi', 'Instrumental Study', [Color(0xFF2193B0), Color(0xFF6DD5ED)], Icons.menu_book),
    _GenreCardData('Workout Energy', 'Workout Motivation', [Color(0xFFFF416C), Color(0xFFFF4B2B)], Icons.fitness_center),
    _GenreCardData('Tidur Pulas', 'Sleep Ambient Music', [Color(0xFF0F2027), Color(0xFF2C5364)], Icons.bedtime),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('spotube_search_history') ?? [];
    if (mounted) {
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _saveSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('spotube_search_history') ?? [];
    list.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    list.insert(0, trimmed);
    if (list.length > 10) {
      list = list.take(10).toList();
    }
    await prefs.setStringList('spotube_search_history', list);
    if (mounted) {
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _removeRecentSearch(String item) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('spotube_search_history') ?? [];
    list.remove(item);
    await prefs.setStringList('spotube_search_history', list);
    if (mounted) {
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _clearAllRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('spotube_search_history');
    if (mounted) {
      setState(() => _recentSearches = []);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _currentQuery = '';
        _results = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _currentQuery = query;
      _isLoading = true;
    });

    _saveSearchQuery(query);
    final res = await _musicService.searchDeezer(query);

    if (mounted && _currentQuery == query) {
      setState(() {
        _results = res;
        _isLoading = false;
      });
    }
  }

  void _applySearchQuery(String query) {
    HapticFeedback.selectionClick();
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: query.length));
    _executeSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Cari Lagu',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12, width: 0.8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _executeSearch(val.trim());
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Apa yang ingin kamu dengarkan?',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Results List or Genre Browse Hub
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                    )
                  : _currentQuery.isNotEmpty
                      ? _buildResultsList(player)
                      : _buildBrowseHub(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(PlayerProvider player) {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied,
              size: 54,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Lagu tidak ditemukan',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 86),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final track = _results[index];
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
            player.playTrack(track, queue: _results);
          },
        );
      },
    );
  }

  Widget _buildBrowseHub() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 86),
      children: [
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pencarian Terkini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: _clearAllRecentSearches,
                child: const Text('Hapus', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((item) {
              return InputChip(
                label: Text(item, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                backgroundColor: AppTheme.surface,
                side: const BorderSide(color: Colors.white12, width: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: () => _applySearchQuery(item),
                onDeleted: () => _removeRecentSearch(item),
                deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Browse All Genres Section
        const Text(
          'Jelajahi Semua Genre & Mood',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: _genres.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final genre = _genres[index];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _applySearchQuery(genre.query);
              },
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: genre.colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: genre.colors.first.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: -10,
                      right: -12,
                      child: Transform.rotate(
                        angle: 0.40,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(-3, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              genre.icon,
                              size: 34,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        genre.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
