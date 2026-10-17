import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/spotify_track.dart';
import '../services/spotify_playback_controller.dart';

class SpotifyPlayerScreen extends StatelessWidget {
  const SpotifyPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = SpotifyPlaybackController.instance;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final track = player.track;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            leading: IconButton(
              tooltip: 'Minimizar player',
              onPressed: () {
                player.minimize();
                Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            ),
            title: Column(
              children: [
                Text('Tocando da playlist', style: AppTextStyles.statLabel),
                Text('PROJETO BOM HOMEM', style: AppTextStyles.eyebrow.copyWith(color: AppColors.textPrimary)),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Abrir faixa no Spotify',
                onPressed: player.openCurrentTrack,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: track == null
                ? _NoTrackState(
                    isReady: player.isReady,
                    error: player.error,
                    onPlay: () => player.startPlaylist(),
                  )
                : _TrackView(player: player, track: track),
          ),
        );
      },
    );
  }
}

class _TrackView extends StatelessWidget {
  const _TrackView({required this.player, required this.track});

  final SpotifyPlaybackController player;
  final SpotifyTrack track;

  @override
  Widget build(BuildContext context) {
    final imageSize = MediaQuery.of(context).size.width - 48;
    final maxImageSize = imageSize.clamp(220.0, 430.0).toDouble();
    final totalMs = player.duration.inMilliseconds;
    final currentMs = player.position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        Center(
          child: Container(
            width: maxImageSize,
            height: maxImageSize,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(.08), blurRadius: 34, spreadRadius: 2)],
            ),
            clipBehavior: Clip.antiAlias,
            child: track.imageUrl.isEmpty
                ? const Center(child: Icon(Icons.music_note_rounded, color: AppColors.orange, size: 90))
                : Image.network(
                    track.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.music_note_rounded, color: AppColors.orange, size: 90)),
                  ),
          ),
        ),
        const SizedBox(height: 23),
        _LyricsPanel(player: player),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.headline.copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(track.artists, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                  if (track.album.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(track.album, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.statLabel),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Abrir no Spotify',
              onPressed: player.openCurrentTrack,
              icon: const Icon(Icons.open_in_new_rounded, color: AppColors.orange),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            min: 0,
            max: totalMs > 0 ? totalMs.toDouble() : 1,
            value: totalMs > 0 ? currentMs.toDouble() : 0,
            activeColor: AppColors.orange,
            inactiveColor: AppColors.inactive,
            onChanged: totalMs <= 0 ? null : (value) => player.seek(Duration(milliseconds: value.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_time(player.position), style: AppTextStyles.statLabel),
              Text(_time(player.duration), style: AppTextStyles.statLabel),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(onPressed: player.previousTrack, icon: const Icon(Icons.skip_previous_rounded, size: 34)),
            SizedBox(
              width: 76,
              height: 76,
              child: FilledButton(
                onPressed: player.togglePlayback,
                style: FilledButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.white, shape: const CircleBorder()),
                child: Icon(player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40),
              ),
            ),
            IconButton(onPressed: player.nextTrack, icon: const Icon(Icons.skip_next_rounded, size: 34)),
          ],
        ),
        if (player.error != null) ...[
          const SizedBox(height: 14),
          Text(player.error!, textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AppColors.orangeLight)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.music_note_rounded, size: 18, color: AppColors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('REPRODUÇÃO PELO SPOTIFY', style: AppTextStyles.eyebrow)),
            TextButton(onPressed: player.openCurrentTrack, child: const Text('Spotify')),
          ],
        ),
      ],
    );
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.player});
  final SpotifyPlaybackController player;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lyrics_outlined, color: AppColors.orange, size: 19),
                const SizedBox(width: 8),
                Text('LETRA', style: AppTextStyles.eyebrow.copyWith(color: AppColors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            if (player.lyricsLoading)
              const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2)))
            else if (player.lyrics != null)
              Text(player.lyrics!, style: AppTextStyles.body.copyWith(height: 1.65, fontSize: 16))
            else
              Text(
                player.lyricsError ?? 'As letras desta faixa serão buscadas automaticamente.',
                style: AppTextStyles.bodySmall,
              ),
            const SizedBox(height: 12),
            Text('Fonte das letras: LRCLIB', style: AppTextStyles.statLabel),
          ],
        ),
      );
}

class _NoTrackState extends StatelessWidget {
  const _NoTrackState({required this.isReady, required this.error, required this.onPlay});
  final bool isReady;
  final String? error;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.graphic_eq_rounded, size: 74, color: AppColors.orange),
              ),
              const SizedBox(height: 24),
              Text('Pronto para tocar', style: AppTextStyles.headline),
              const SizedBox(height: 8),
              Text(
                error ?? (isReady ? 'Inicie a playlist oficial para abrir o player.' : 'Conectando ao Spotify…'),
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Tocar playlist oficial'),
              ),
            ],
          ),
        ),
      );
}

String _time(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
