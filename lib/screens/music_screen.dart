import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/spotify_playlist.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/spotify_playback_controller.dart';
import 'spotify_player_screen.dart';
import 'spotify_playlist_tracks_screen.dart';

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = SpotifyPlaybackController.instance;
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: player,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Música', style: AppTextStyles.brandHeadline),
                ),
                IconButton(
                  tooltip: 'Ver músicas da playlist',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SpotifyPlaylistTracksScreen(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.queue_music_rounded,
                    color: AppColors.orange,
                    size: 27,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Uma trilha para fortalecer foco, propósito e disciplina.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 20),
            _PlaylistCard(
              isConfigured: player.isConfigured,
              isAuthenticated: player.isAuthenticated,
              isReady: player.isReady,
              isBusy: player.isBusy,
              isPlaying: player.isPlaying,
              trackTitle: player.track?.name,
              artist: player.track?.artists,
              imageUrl: player.track?.imageUrl,
              onConnect: player.connect,
              onPlay: () async {
                await player.startPlaylist();
                if (!context.mounted || !player.isAuthenticated) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SpotifyPlayerScreen(),
                  ),
                );
              },
              onOpenPlayer: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SpotifyPlayerScreen(),
                ),
              ),
              error: player.error,
            ),
            const SizedBox(height: 24),
            if (!kIsWeb) ...[
              Text(
                'Controle suas músicas aqui no PBH. No Android, o Spotify toca em segundo plano e precisa estar instalado e conectado à sua conta. Na primeira conexão, autorize o controle da reprodução. Os controles completos exigem Spotify Premium.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    if (await launchUrl(
                      Uri.parse('spotify:playlist:$officialSpotifyPlaylistId'),
                      mode: LaunchMode.externalApplication,
                    ))
                      return;
                  } catch (_) {
                    // The web playlist remains accessible without the native app.
                  }
                  await launchUrl(
                    Uri.parse(officialSpotifyPlaylistUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir playlist no Spotify'),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Sua música, no ritmo do PBH',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),
            const _FeatureRow(
              icon: Icons.album_outlined,
              title: 'Controles completos',
              body:
                  'Veja a faixa, a capa e o progresso. Pause, avance ou volte sem sair do app.',
            ),
            const SizedBox(height: 10),
            const _FeatureRow(
              icon: Icons.lyrics_outlined,
              title: 'Letras disponíveis',
              body:
                  'Quando houver letra cadastrada para a faixa, ela aparece no player.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.isConfigured,
    required this.isAuthenticated,
    required this.isReady,
    required this.isBusy,
    required this.isPlaying,
    required this.onConnect,
    required this.onPlay,
    required this.onOpenPlayer,
    required this.error,
    this.trackTitle,
    this.artist,
    this.imageUrl,
  });

  final bool isConfigured;
  final bool isAuthenticated;
  final bool isReady;
  final bool isBusy;
  final bool isPlaying;
  final String? trackTitle;
  final String? artist;
  final String? imageUrl;
  final VoidCallback onConnect;
  final VoidCallback onPlay;
  final VoidCallback onOpenPlayer;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final title = trackTitle ?? 'Projeto Bom Homem';
    final subtitle = trackTitle == null ? 'Playlist oficial' : (artist ?? '');
    final actionText = !isConfigured
        ? 'Player em configuração'
        : !isAuthenticated
        ? 'Conectar ao Spotify'
        : !isReady
        ? 'Conectando player…'
        : trackTitle != null
        ? 'Abrir player'
        : 'Tocar playlist oficial';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.42,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl!.isNotEmpty)
                    Container(
                      color: Colors.black,
                      child: Image.network(imageUrl!, fit: BoxFit.contain),
                    )
                  else
                    Image.asset('assets/images/spotify.png', fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xEE000000)],
                        stops: [.25, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Row(
                      children: [
                        _CoverThumb(imageUrl: imageUrl),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (trackTitle != null)
                          IconButton(
                            onPressed: onOpenPlayer,
                            tooltip: 'Abrir player',
                            icon: const Icon(
                              Icons.open_in_full_rounded,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isPlaying)
                    const Positioned(top: 17, left: 18, child: _PlayingBadge()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PLAYLIST OFICIAL',
                    style: AppTextStyles.eyebrow.copyWith(
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('Projeto Bom Homem', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Ouça sua playlist e acompanhe a faixa, o progresso e as letras disponíveis.',
                    style: AppTextStyles.bodySmall,
                  ),
                  if (error != null && error!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.orangeLight,
                      ),
                    ),
                  ],
                  if (isAuthenticated && !isReady) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Conectando o player Spotify…',
                      style: AppTextStyles.statLabel,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          !isConfigured ||
                              isBusy ||
                              (isAuthenticated && !isReady)
                          ? null
                          : (!isAuthenticated
                                ? onConnect
                                : (trackTitle != null ? onOpenPlayer : onPlay)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                      ),
                      icon: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              !isAuthenticated
                                  ? Icons.link_rounded
                                  : (trackTitle != null
                                        ? Icons.graphic_eq_rounded
                                        : Icons.play_arrow_rounded),
                            ),
                      label: Text(isBusy ? 'Conectando…' : actionText),
                    ),
                  ),
                  if (isAuthenticated) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed:
                            SpotifyPlaybackController.instance.disconnect,
                        icon: const Icon(Icons.logout_rounded, size: 17),
                        label: const Text('Desconectar Spotify'),
                      ),
                    ),
                  ],
                  if (!isConfigured) ...[
                    const SizedBox(height: 10),
                    Text(
                      'O Spotify ainda não foi configurado nesta versão do aplicativo.',
                      style: AppTextStyles.statLabel,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 48,
      height: 48,
      child: imageUrl == null || imageUrl!.isEmpty
          ? const ColoredBox(
              color: AppColors.backgroundElevated,
              child: Icon(Icons.music_note, color: AppColors.orange),
            )
          : Image.network(imageUrl!, fit: BoxFit.cover),
    ),
  );
}

class _PlayingBadge extends StatelessWidget {
  const _PlayingBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(.62),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.graphic_eq_rounded, size: 15, color: AppColors.orange),
        SizedBox(width: 6),
        Text(
          'TOCANDO',
          style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1),
        ),
      ],
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.orange, size: 22),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(body, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}
