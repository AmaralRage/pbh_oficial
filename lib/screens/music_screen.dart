import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/spotify_playlist.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text('Música', style: AppTextStyles.headline),
          const SizedBox(height: 6),
          Text('Uma trilha para fortalecer foco, propósito e disciplina.', style: AppTextStyles.bodySmall),
          const SizedBox(height: 26),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF9B3DFF).withOpacity(.7)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/spotify.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF19042B)),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(.12), Colors.black.withOpacity(.86)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(color: Colors.black.withOpacity(.38), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.graphic_eq, size: 30, color: Colors.white),
                        ),
                        const SizedBox(height: 126),
                        Text('PLAYLIST OFICIAL', style: AppTextStyles.eyebrow.copyWith(color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(
                          'Projeto Bom Homem',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Músicas para acompanhar sua jornada de evolução.',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withOpacity(.88)),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleSpotifyTap(context),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF121212)),
                            icon: const Icon(Icons.play_circle_fill),
                            label: Text(hasOfficialSpotifyPlaylist ? 'Ouvir no Spotify' : 'Playlist em preparação'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Por que esta playlist?', style: AppTextStyles.titleMedium),
          const SizedBox(height: 14),
          const _MusicBenefit(
            icon: Icons.track_changes_outlined,
            title: 'Foco para agir',
            description: 'Uma seleção pensada para os seus momentos de treino, trabalho e rotina.',
          ),
          const SizedBox(height: 10),
          const _MusicBenefit(
            icon: Icons.favorite_outline,
            title: 'Conexão com a jornada',
            description: 'Ouça junto com outros homens que escolheram viver com mais intenção.',
          ),
        ],
      ),
    );
  }

  void _handleSpotifyTap(BuildContext context) {
    if (!hasOfficialSpotifyPlaylist) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Envie o link da playlist oficial para conectá-la ao Spotify.')),
      );
      return;
    }

    final playlistUri = Uri.parse(officialSpotifyPlaylistUrl);
    launchUrl(playlistUri, mode: LaunchMode.externalApplication).then((opened) {
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir a playlist no Spotify.')),
        );
      }
    });
  }
}

class _MusicBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _MusicBenefit({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.orange, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 15)),
                const SizedBox(height: 3),
                Text(description, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
