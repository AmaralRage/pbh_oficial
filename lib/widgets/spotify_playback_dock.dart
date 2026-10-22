import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/spotify_playback_controller.dart';
import '../screens/spotify_player_screen.dart';

class SpotifyPlaybackDock extends StatelessWidget {
  const SpotifyPlaybackDock({super.key});

  @override
  Widget build(BuildContext context) {
    final player = SpotifyPlaybackController.instance;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final track = player.track;
        if (!player.opened || track == null) return const SizedBox.shrink();
        return Container(
          height: 68,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: context.pbhColors.surfaceElevated,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: context.pbhColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.32),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          player.expand();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SpotifyPlayerScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              _MiniArtwork(imageUrl: track.imageUrl),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      track.artists,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.statLabel,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Faixa anterior',
                                onPressed: player.previousTrack,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.skip_previous_rounded,
                                  color: context.pbhColors.textSecondary,
                                  size: 25,
                                ),
                              ),
                              IconButton(
                                tooltip: player.isPlaying
                                    ? 'Pausar'
                                    : 'Reproduzir',
                                onPressed: player.togglePlayback,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  player.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: context.pbhColors.textPrimary,
                                  size: 28,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Avançar faixa',
                                onPressed: player.nextTrack,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.skip_next_rounded,
                                  color: context.pbhColors.textSecondary,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    LinearProgressIndicator(
                      minHeight: 2,
                      value: player.duration.inMilliseconds == 0
                          ? 0
                          : (player.position.inMilliseconds /
                                    player.duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(
                        context.pbhColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 46,
      height: 46,
      child: imageUrl.isEmpty
          ? ColoredBox(
              color: context.pbhColors.background,
              child: Icon(
                Icons.music_note_rounded,
                color: context.pbhColors.orange,
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: context.pbhColors.background,
                child: Icon(
                  Icons.music_note_rounded,
                  color: context.pbhColors.orange,
                ),
              ),
            ),
    ),
  );
}
