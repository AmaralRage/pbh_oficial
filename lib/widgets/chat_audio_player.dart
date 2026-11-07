import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ChatAudioPlayback {
  static AudioPlayer? active;
  static Future<void> pauseAll() async {
    await active?.pause();
  }
}

class ChatAudioPlayer extends StatefulWidget {
  const ChatAudioPlayer({
    super.key,
    required this.load,
    required this.durationMs,
    required this.format,
  });
  final Future<Uint8List> Function() load;
  final int durationMs;
  final String format;
  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer>
    with WidgetsBindingObserver {
  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription>[];
  Uint8List? _bytes;
  bool _loading = false, _playing = false, _failed = false;
  int _position = 0;
  double _speed = 1;
  Future<void> _changeSpeed() async {
    final next = _speed == 1
        ? 1.5
        : _speed == 1.5
        ? 2.0
        : 1.0;
    try {
      await _player?.setPlaybackRate(next);
      if (mounted) setState(() => _speed = next);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _time(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player?.pause();
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // Authorization is checked again by load(), even when the service caches bytes.
      _bytes = await widget.load();
      if (!mounted ||
          !(ModalRoute.of(context)?.isCurrent ?? true) ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed))
        return;
      if (_player == null) {
        _player = AudioPlayer();
        _subscriptions.add(
          _player!.onPlayerStateChanged.listen((state) {
            if (mounted)
              setState(() => _playing = state == PlayerState.playing);
          }),
        );
        _subscriptions.add(
          _player!.onPositionChanged.listen((position) {
            if (mounted)
              setState(
                () => _position = position.inMilliseconds.clamp(
                  0,
                  widget.durationMs,
                ),
              );
          }),
        );
        _subscriptions.add(
          _player!.onPlayerComplete.listen((_) {
            if (mounted) setState(() => _position = 0);
          }),
        );
      }
      if (ChatAudioPlayback.active != _player)
        await ChatAudioPlayback.pauseAll();
      ChatAudioPlayback.active = _player;
      await _player!.setPlaybackRate(_speed);
      if (_position > 0)
        await _player!.resume();
      else
        await _player!.play(
          BytesSource(
            _bytes!,
            mimeType: widget.format == 'm4a' ? 'audio/mp4' : 'audio/webm',
          ),
        );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed)
      unawaited(_player?.pause() ?? Future<void>.value());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    if (ChatAudioPlayback.active == _player) ChatAudioPlayback.active = null;
    final player = _player;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: _playing
                  ? 'Pausar áudio'
                  : _failed
                  ? 'Tentar ouvir novamente'
                  : 'Ouvir áudio',
              onPressed: _loading ? null : _toggle,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: context.pbhColors.orange,
                    ),
            ),
            Expanded(
              child: Slider(
                value: _position.toDouble().clamp(
                  0,
                  widget.durationMs.toDouble(),
                ),
                min: 0,
                max: widget.durationMs.toDouble().clamp(1, 120000),
                activeColor: context.pbhColors.orange,
                onChanged: _player == null || _loading
                    ? null
                    : (value) {
                        setState(() => _position = value.toInt());
                      },
                onChangeEnd: _player == null || _loading
                    ? null
                    : (value) =>
                          _player!.seek(Duration(milliseconds: value.toInt())),
              ),
            ),
            Text(
              _time(_playing || _position > 0 ? _position : widget.durationMs),
              style: const TextStyle(fontSize: 12),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(40, 40),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              onPressed: _loading ? null : _changeSpeed,
              child: Text(
                '${_speed == 1.5 ? '1,5' : _speed.toInt()}×',
                semanticsLabel:
                    'Velocidade ${_speed.toString().replaceAll('.', ',')} vezes',
              ),
            ),
          ],
        ),
        if (_failed)
          const Text(
            'Não foi possível ouvir. Toque para tentar novamente.',
            style: TextStyle(fontSize: 11),
          ),
      ],
    ),
  );
}
