import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/spotify_track.dart';
import '../services/spotify_playback_controller.dart';
import '../widgets/spotify_playback_dock.dart';
import 'spotify_player_screen.dart';

class SpotifyTrackSearchScreen extends StatefulWidget {
  const SpotifyTrackSearchScreen({super.key});

  @override
  State<SpotifyTrackSearchScreen> createState() => _SpotifyTrackSearchScreenState();
}

class _SpotifyTrackSearchScreenState extends State<SpotifyTrackSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  List<SpotifyTrack> _tracks = const [];
  bool _loading = false;
  String? _error;
  String? _playingUri;
  int _searchVersion = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final version = ++_searchVersion;
    if (value.trim().length < 2) {
      setState(() {
        _tracks = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value.trim(), version));
  }

  Future<void> _search(String query, int version) async {
    try {
      final tracks = await SpotifyPlaybackController.instance.searchTracks(query);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
        _error = null;
      });
    } catch (exception) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _tracks = const [];
        _loading = false;
        _error = exception.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _playTrack(SpotifyTrack track) async {
    setState(() => _playingUri = track.uri);
    try {
      await SpotifyPlaybackController.instance.playTrack(track);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SpotifyPlayerScreen()));
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _playingUri = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = SpotifyPlaybackController.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Buscar músicas')),
      body: AnimatedBuilder(
        animation: player,
        builder: (context, _) {
          if (!player.isAuthenticated) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded, color: AppColors.orange, size: 42),
                    const SizedBox(height: 14),
                    Text('Conecte o Spotify para buscar e tocar músicas.', style: AppTextStyles.body, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: player.connect,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Conectar ao Spotify'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: TextField(
                  controller: _queryController,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar música ou artista',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _queryController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              _queryController.clear();
                              _onQueryChanged('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                    : _error != null
                        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySmall)))
                        : _queryController.text.trim().length < 2
                            ? Center(child: Text('Digite pelo menos 2 caracteres para buscar.', style: AppTextStyles.bodySmall))
                            : _tracks.isEmpty
                                ? Center(child: Text('Nenhuma música encontrada.', style: AppTextStyles.bodySmall))
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                    itemCount: _tracks.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                                    itemBuilder: (context, index) {
                                      final track = _tracks[index];
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        leading: _TrackArtwork(track: track),
                                        title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                                        subtitle: Text(
                                          [track.artists, track.album].where((value) => value.isNotEmpty).join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.statLabel,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Abrir no Spotify',
                                              onPressed: () => player.openTrack(track),
                                              icon: const Icon(Icons.open_in_new_rounded, color: AppColors.textTertiary, size: 20),
                                            ),
                                            if (_playingUri == track.uri)
                                              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange))
                                            else
                                              const Icon(Icons.play_circle_fill_rounded, color: AppColors.orange, size: 28),
                                          ],
                                        ),
                                        onTap: () => _playTrack(track),
                                      );
                                    },
                                  ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_note_rounded, color: AppColors.orange, size: 17),
                    const SizedBox(width: 6),
                    Text('Busca e reprodução pelo Spotify', style: AppTextStyles.statLabel),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const SpotifyPlaybackDock(),
    );
  }
}

class _TrackArtwork extends StatelessWidget {
  const _TrackArtwork({required this.track});

  final SpotifyTrack track;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: track.imageUrl.isEmpty
              ? const ColoredBox(color: AppColors.surface, child: Icon(Icons.music_note_rounded, color: AppColors.orange))
              : Image.network(track.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surface, child: Icon(Icons.music_note_rounded, color: AppColors.orange))),
        ),
      );
}
