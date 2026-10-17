import 'package:flutter/material.dart';

import '../core/config/spotify_playlist.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/spotify_track.dart';
import '../services/spotify_playback_controller.dart';
import '../widgets/spotify_playback_dock.dart';

class SpotifyPlaylistTracksScreen extends StatefulWidget {
  const SpotifyPlaylistTracksScreen({super.key});

  @override
  State<SpotifyPlaylistTracksScreen> createState() => _SpotifyPlaylistTracksScreenState();
}

class _SpotifyPlaylistTracksScreenState extends State<SpotifyPlaylistTracksScreen> {
  final TextEditingController _queryController = TextEditingController();
  final SpotifyPlaybackController _player = SpotifyPlaybackController.instance;
  List<SpotifyTrack> _tracks = const [];
  bool _loading = false;
  bool _loaded = false;
  bool _requiresReconnect = false;
  bool _reauthorizing = false;
  String? _error;
  String? _playingUri;

  @override
  void initState() {
    super.initState();
    _player.addListener(_onPlayerChanged);
    if (_player.isAuthenticated) _loadPlaylist();
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onPlayerChanged() {
    if (_reauthorizing && !_player.isBusy) {
      _reauthorizing = false;
      if (_player.error != null) {
        setState(() {
          _loaded = true;
          _error = _player.error;
          _requiresReconnect = true;
        });
      } else {
        _loaded = false;
        _loadPlaylist();
      }
      return;
    }
    if (!_player.isAuthenticated && _loaded && mounted) {
      setState(() {
        _loaded = false;
        _tracks = const [];
      });
    }
    if (_player.isAuthenticated && !_loaded && !_loading) _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracks = await _player.loadPlaylistTracks();
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loaded = true;
        _loading = false;
        _requiresReconnect = false;
      });
    } catch (exception) {
      if (!mounted) return;
      final message = exception.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
      setState(() {
        _requiresReconnect = message.contains('HTTP 403');
        _error = message.contains('403')
            ? 'O Spotify negou acesso à playlist. A conta conectada precisa ser proprietária ou colaboradora dela. Reconecte para conceder a permissão de leitura.'
            : message;
        _loaded = true;
        _loading = false;
      });
    }
  }

  Future<void> _retryPlaylistLoad() async {
    if (_requiresReconnect) {
      _reauthorizing = true;
      await _player.connect(forceConsent: true);
      return;
    }
    setState(() => _loaded = false);
    await _loadPlaylist();
  }

  Future<void> _playTrack(SpotifyTrack track) async {
    setState(() => _playingUri = track.uri);
    try {
      await _player.playPlaylistTrack(track, officialSpotifyPlaylistId);
      if (!mounted) return;
      Navigator.of(context).maybePop();
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
    final query = _queryController.text.trim().toLowerCase();
    final filteredTracks = _tracks.where((track) {
      if (query.isEmpty) return true;
      return track.name.toLowerCase().contains(query) || track.artists.toLowerCase().contains(query);
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Músicas da playlist'),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            onPressed: _loading ? null : () {
              setState(() => _loaded = false);
              _loadPlaylist();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _player,
        builder: (context, _) {
          if (!_player.isAuthenticated) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded, color: AppColors.orange, size: 42),
                    const SizedBox(height: 14),
                    Text('Conecte o Spotify para ver e tocar as faixas da playlist.', style: AppTextStyles.body, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _player.connect,
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROJETO BOM HOMEM', style: AppTextStyles.eyebrow),
                    const SizedBox(height: 4),
                    Text('${_tracks.length} faixas na playlist', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _queryController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Filtrar faixas desta lista',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _queryController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar filtro',
                                onPressed: () {
                                  _queryController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: _retryPlaylistLoad,
                                    icon: Icon(_requiresReconnect ? Icons.link_rounded : Icons.refresh_rounded),
                                    label: Text(_requiresReconnect ? 'Reconectar Spotify' : 'Tentar novamente'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : filteredTracks.isEmpty
                            ? Center(
                                child: Text(
                                  query.isEmpty ? 'A playlist não possui faixas disponíveis.' : 'Nenhuma faixa encontrada nesta playlist.',
                                  style: AppTextStyles.bodySmall,
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: filteredTracks.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                                itemBuilder: (context, index) {
                                  final track = filteredTracks[index];
                                  final isCurrent = _player.track?.uri == track.uri;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    leading: _TrackArtwork(track: track),
                                    title: Text(
                                      track.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontSize: 14,
                                        color: isCurrent ? AppColors.orange : AppColors.textPrimary,
                                      ),
                                    ),
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
                                          onPressed: () => _player.openTrack(track),
                                          icon: const Icon(Icons.open_in_new_rounded, color: AppColors.textTertiary, size: 19),
                                        ),
                                        if (_playingUri == track.uri)
                                          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange))
                                        else
                                          Icon(
                                            isCurrent && _player.isPlaying ? Icons.equalizer_rounded : Icons.play_circle_fill_rounded,
                                            color: AppColors.orange,
                                            size: 27,
                                          ),
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
                    Text('Playlist e reprodução pelo Spotify', style: AppTextStyles.statLabel),
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
              : Image.network(
                  track.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surface, child: Icon(Icons.music_note_rounded, color: AppColors.orange)),
                ),
        ),
      );
}
