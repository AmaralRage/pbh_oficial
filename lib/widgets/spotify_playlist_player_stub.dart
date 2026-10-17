import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/spotify_playlist.dart';
import '../core/theme/app_colors.dart';

class SpotifyPlaylistPlayer extends StatelessWidget {
  const SpotifyPlaylistPlayer({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new_rounded, color: AppColors.orange, size: 32),
            const SizedBox(height: 12),
            const Text(
              'O player incorporado está disponível na versão web. No celular, abra a playlist no Spotify.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(officialSpotifyPlaylistUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Abrir no Spotify'),
            ),
          ],
        ),
      );
}
