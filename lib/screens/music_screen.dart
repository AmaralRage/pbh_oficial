import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/spotify_playlist.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/spotify_playlist_player.dart';

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
          const SizedBox(height: 18),
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
                          'Ouça as faixas da playlist oficial sem sair do PBH.',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withOpacity(.88)),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: hasOfficialSpotifyPlaylist
                                ? () => _openSpotifyPlayer(context)
                                : null,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF121212)),
                            icon: const Icon(Icons.play_circle_fill),
                            label: Text(hasOfficialSpotifyPlaylist ? 'Abrir player' : 'Playlist em preparação'),
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

  void _openSpotifyPlayer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.graphic_eq, color: AppColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Playlist oficial', style: AppTextStyles.titleMedium),
                ),
                IconButton(
                  tooltip: 'Fechar player',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Toque em ▶ no player para começar. O Spotify pode oferecer apenas uma prévia dependendo do navegador e da sessão.',
              style: AppTextStyles.statLabel,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const SpotifyPlaylistPlayer(),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(officialSpotifyPlaylistUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir no aplicativo Spotify'),
            ),
          ],
        ),
      ),
    );
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
