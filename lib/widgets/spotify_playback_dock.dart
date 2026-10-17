import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/spotify_playlist.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/spotify_playback_controller.dart';
import 'spotify_playlist_player.dart';

class SpotifyPlaybackDock extends StatelessWidget {
  const SpotifyPlaybackDock({super.key});

  static const _playerHeight = 352.0;
  static const _headerHeight = 68.0;
  static const _miniHeight = 70.0;

  @override
  Widget build(BuildContext context) {
    final controller = SpotifyPlaybackController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.opened) return const SizedBox.shrink();

        final expanded = controller.expanded;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          height: expanded ? _headerHeight + _playerHeight : _miniHeight,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 18, offset: const Offset(0, -4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Keep this exact widget mounted while the dock is minimized.
                Positioned(
                  top: expanded ? _headerHeight : 0,
                  left: 0,
                  right: 0,
                  height: _playerHeight,
                  child: const SpotifyPlaylistPlayer(
                    key: ValueKey('persistent-spotify-embed'),
                  ),
                ),
                if (expanded)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _headerHeight,
                    child: _ExpandedHeader(
                      onMinimize: controller.minimize,
                      onOpenSpotify: _openSpotifyApp,
                    ),
                  )
                else
                  Positioned.fill(
                    child: _MiniPlayerBar(onExpand: controller.expand),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSpotifyApp() async {
    await launchUrl(
      Uri.parse(officialSpotifyPlaylistUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}

class _ExpandedHeader extends StatelessWidget {
  const _ExpandedHeader({required this.onMinimize, required this.onOpenSpotify});

  final VoidCallback onMinimize;
  final VoidCallback onOpenSpotify;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.only(left: 16, right: 6),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq, color: AppColors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Playlist oficial', style: AppTextStyles.titleMedium),
                  Text('Toque em ▶ para iniciar', style: AppTextStyles.statLabel),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Abrir no aplicativo Spotify',
              onPressed: onOpenSpotify,
              icon: const Icon(Icons.open_in_new_rounded),
            ),
            IconButton(
              tooltip: 'Minimizar e continuar tocando',
              onPressed: onMinimize,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ),
      );
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.orangeDim,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.graphic_eq, color: AppColors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Playlist oficial', style: AppTextStyles.titleMedium, maxLines: 1),
                      Text('Player Spotify mantido aberto', style: AppTextStyles.statLabel, maxLines: 1),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Abrir controles do Spotify',
                  onPressed: onExpand,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.orange),
                ),
              ],
            ),
          ),
        ),
      );
}
