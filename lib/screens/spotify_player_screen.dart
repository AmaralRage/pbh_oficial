import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/spotify_track.dart';
import '../services/spotify_playback_controller.dart';
import 'spotify_playlist_tracks_screen.dart';

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
                tooltip: 'Ver músicas da playlist',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SpotifyPlaylistTracksScreen()),
                ),
                icon: const Icon(Icons.queue_music_rounded, color: AppColors.orange),
              ),
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
    final maxImageSize = (MediaQuery.of(context).size.width - 48).clamp(0.0, 430.0).toDouble();
    final totalMs = player.duration.inMilliseconds;
    final currentMs = player.position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (track.imageUrl.isNotEmpty)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 900),
                    child: ImageFiltered(
                      key: ValueKey('background-${track.imageUrl}'),
                      imageFilter: ui.ImageFilter.blur(sigmaX: 72, sigmaY: 72),
                      child: Opacity(
                        opacity: .46,
                        child: Image.network(track.imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x48080808),
                        Color(0xB8080808),
                        Color(0xE6080808),
                      ],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ListView(
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
            child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: .97, end: 1).animate(animation),
                        child: child,
                      ),
                    ),
                    child: track.imageUrl.isEmpty
                        ? const Center(
                            key: ValueKey('no-album-art'),
                            child: Icon(Icons.music_note_rounded, color: AppColors.orange, size: 90),
                          )
                        : Image.network(
                            track.imageUrl,
                            key: ValueKey(track.imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              key: ValueKey('album-art-error'),
                              child: Icon(Icons.music_note_rounded, color: AppColors.orange, size: 90),
                            ),
                          ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_time(player.position), style: AppTextStyles.statLabel),
              Text(_time(player.duration), style: AppTextStyles.statLabel),
            ],
          ),
        ),
        const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: player.shuffleEnabled ? 'Desativar reprodução aleatória' : 'Ativar reprodução aleatória',
                      onPressed: () => player.setShuffle(!player.shuffleEnabled),
                      color: player.shuffleEnabled ? AppColors.orange : AppColors.textPrimary,
                      icon: const Icon(Icons.shuffle_rounded),
                    ),
                    IconButton(onPressed: player.previousTrack, icon: const Icon(Icons.skip_previous_rounded, size: 34)),
                    const SizedBox(width: 76),
                    IconButton(onPressed: player.nextTrack, icon: const Icon(Icons.skip_next_rounded, size: 34)),
                    IconButton(
                      tooltip: player.repeatMode == 0
                          ? 'Ativar repetição da playlist'
                          : player.repeatMode == 1
                              ? 'Repetir faixa atual'
                              : 'Desativar repetição',
                      onPressed: () => player.setRepeatMode((player.repeatMode + 1) % 3),
                      color: player.repeatMode == 0 ? AppColors.textPrimary : AppColors.orange,
                      icon: Icon(player.repeatMode == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded),
                    ),
                  ],
                ),
              SizedBox(
                width: 76,
                height: 76,
                child: FilledButton(
                  onPressed: player.togglePlayback,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: player.isPlaying
                        ? const SizedBox(
                            key: ValueKey('pause'),
                            width: 76,
                            height: 76,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 29,
                                  top: 26,
                                  child: _PauseBar(),
                                ),
                                Positioned(
                                  left: 41,
                                  top: 26,
                                  child: _PauseBar(),
                                ),
                              ],
                            ),
                          )
                        : const Icon(
                            Icons.play_arrow_rounded,
                            key: ValueKey('play'),
                            size: 40,
                          ),
                  ),
                ),
              ),
            ],
              ),
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
        const SizedBox(height: 12),
        _LyricsPanel(player: player),
          ],
        ),
      ],
    );
  }
}

class _PauseBar extends StatelessWidget {
  const _PauseBar();

  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

class _LyricsPanel extends StatefulWidget {
  const _LyricsPanel({required this.player});
  final SpotifyPlaybackController player;

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _lineKeys = [];
  int _lastAutoScrolledIndex = -1;
  String _linesSignature = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final lines = player.lyricLines;
    if (lines.length != _lineKeys.length) {
      _lineKeys = List.generate(lines.length, (_) => GlobalKey());
    }

    final signature = lines.map((line) => '${line.timestamp?.inMilliseconds}:${line.text}').join('|');
    if (_linesSignature != signature) {
      _linesSignature = signature;
      _lastAutoScrolledIndex = -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) _scrollController.jumpTo(0);
      });
    }

    final activeIndex = player.activeLyricIndex;
    if (activeIndex >= 0 && activeIndex != _lastAutoScrolledIndex && activeIndex < _lineKeys.length) {
      _lastAutoScrolledIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lineContext = _lineKeys[activeIndex].currentContext;
        if (mounted && lineContext != null) {
          final renderObject = lineContext.findRenderObject();
          if (renderObject != null && _scrollController.hasClients) {
            final viewport = RenderAbstractViewport.of(renderObject);
            final position = _scrollController.position;
            final target = viewport.getOffsetToReveal(renderObject, .45).offset;
            _scrollController.animateTo(
              target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble(),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            );
          }
        }
      });
    }

    return Container(
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
            SizedBox(
              height: 220,
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: List.generate(lines.length, (index) {
                    final line = lines[index];
                    final isActive = player.lyricsAreSynced && index == activeIndex;
                    final isPast = player.lyricsAreSynced && activeIndex > index;
                    if (line.text == '\u266a') {
                      return Padding(
                        key: _lineKeys[index],
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.orangeDim : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.music_note_rounded,
                            color: isActive ? AppColors.orange : AppColors.textTertiary,
                            size: isActive ? 24 : 20,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      key: _lineKeys[index],
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.orangeDim : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: AppTextStyles.body.copyWith(
                            color: isActive
                                ? AppColors.textPrimary
                                : isPast
                                    ? AppColors.textSecondary.withOpacity(.62)
                                    : AppColors.textSecondary,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                            height: 1.5,
                            fontSize: isActive ? 16 : 15,
                          ),
                          child: Text(line.text),
                        ),
                      ),
                    );
                    }),
                  ),
                ),
              ),
            )
          else if (player.lyricsError == 'A letra desta faixa não está disponível.')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.music_note_rounded, color: AppColors.orange, size: 28),
                    SizedBox(height: 8),
                    Text('Sem letra disponível para esta faixa.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.lyricsError ?? 'As letras desta faixa serão buscadas automaticamente.',
                  style: AppTextStyles.bodySmall,
                ),
                if (player.lyricsError != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: player.retryLyrics,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Tentar carregar novamente'),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          Text('Fonte das letras: LRCLIB', style: AppTextStyles.statLabel),
        ],
      ),
    );
  }
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
