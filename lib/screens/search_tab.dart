import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../theme/app_theme.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final MusicService _musicService = MusicService();
  Timer? _debounce;
  List<TrackModel> _results = [];
  bool _isLoading = false;
  String _currentQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

    final res = await _musicService.searchDeezer(query);

    if (mounted && _currentQuery == query) {
      setState(() {
        _results = res;
        _isLoading = false;
      });
    }
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Apa yang ingin kamu dengarkan?',
                    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    prefixIcon: const Icon(LucideIcons.search, color: AppTheme.textSecondary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, color: AppTheme.textSecondary, size: 18),
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

            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                    )
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _currentQuery.isEmpty ? LucideIcons.search : LucideIcons.frown,
                                size: 54,
                                color: AppTheme.textSecondary.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _currentQuery.isEmpty
                                    ? 'Cari lagu, artis, atau album'
                                    : 'Lagu tidak ditemukan',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final track = _results[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: CachedNetworkImage(
                                  imageUrl: track.artworkUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(color: AppTheme.card),
                                  errorWidget: (_, _, _) => Container(
                                    color: AppTheme.card,
                                    child: const Icon(LucideIcons.music, size: 24),
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
                              trailing: const Icon(LucideIcons.playCircle, color: AppTheme.textSecondary, size: 22),
                              onTap: () => player.playTrack(track, queue: _results),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
