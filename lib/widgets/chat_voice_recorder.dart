import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../core/theme/app_colors.dart';
import '../models/chat_models.dart';
import '../services/chat_recording_files.dart';
import '../services/community_service.dart';
import 'chat_audio_player.dart';

class ChatVoiceRecorder extends StatefulWidget {
  const ChatVoiceRecorder({
    super.key,
    this.recorder,
    this.readRecordingBytes,
    this.pathForRecording,
  });
  final AudioRecorder? recorder;
  final Future<Uint8List> Function(String)? readRecordingBytes;
  final Future<String> Function(String, String)? pathForRecording;
  @override
  State<ChatVoiceRecorder> createState() => _ChatVoiceRecorderState();
}

class _ChatVoiceRecorderState extends State<ChatVoiceRecorder>
    with WidgetsBindingObserver {
  late AudioRecorder _recorder = widget.recorder ?? AudioRecorder();
  final _watch = Stopwatch();
  Timer? _ticker, _limit;
  bool _recording = false, _busy = true;
  String? _error;
  String _format = 'm4a';
  ChatVoice? _voice;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    try {
      await ChatAudioPlayback.pauseAll();
      if (!await _recorder.hasPermission())
        throw StateError(
          'Permita o microfone nas configurações do celular ou navegador para gravar.',
        );
      if (!mounted) return;
      if (WidgetsBinding.instance.lifecycleState != null &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
        throw StateError('Volte à conversa para gravar sua mensagem.');
      final encoder =
          kIsWeb && await _recorder.isEncoderSupported(AudioEncoder.opus)
          ? AudioEncoder.opus
          : AudioEncoder.aacLc;
      if (!await _recorder.isEncoderSupported(encoder))
        throw StateError(
          'Este aparelho não oferece um formato de voz compatível.',
        );
      _format = encoder == AudioEncoder.opus ? 'webm' : 'm4a';
      final path = await (widget.pathForRecording ?? recordingPath)(
        CommunityService.newPostId(),
        _format,
      );
      if (!mounted) return;
      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: 32000,
          sampleRate: encoder == AudioEncoder.opus ? 48000 : 24000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      if (!mounted ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        await _recorder.cancel();
        if (mounted)
          setState(() {
            _busy = false;
            _error =
                'Gravação interrompida. Volte à conversa e tente novamente.';
          });
        return;
      }
      _watch.start();
      setState(() {
        _recording = true;
        _busy = false;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
      // Leave a small margin for the encoder's final audio frame; the server enforces 120 s.
      _limit = Timer(const Duration(milliseconds: 119500), _finish);
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error is StateError
              ? error.message.toString()
              : 'Não foi possível iniciar o microfone. Confira a permissão e tente novamente.';
          _busy = false;
        });
    }
  }

  Future<void> _finish() async {
    if (_busy || !_recording) return;
    setState(() => _busy = true);
    _ticker?.cancel();
    _limit?.cancel();
    _watch.stop();
    try {
      final path = await _recorder.stop();
      if (path == null) throw StateError('Gravação indisponível.');
      final bytes = await (widget.readRecordingBytes ?? readRecording)(path);
      if (bytes.isEmpty || _watch.elapsedMilliseconds < 250)
        throw StateError('Grave uma mensagem um pouco maior.');
      if (!mounted) return;
      setState(
        () => _voice = ChatVoice(
          bytes: bytes,
          format: _format,
          durationMs: _watch.elapsedMilliseconds.clamp(1, 120000),
        ),
      );
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Não foi possível salvar a gravação. Tente novamente.',
        );
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _recording = false;
        });
    }
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _voice = null;
      _recording = false;
    });
    _ticker?.cancel();
    _limit?.cancel();
    _watch
      ..stop()
      ..reset();
    try {
      await _recorder.cancel().whenComplete(_recorder.dispose);
    } catch (_) {}
    if (!mounted) return;
    _recorder = widget.recorder ?? AudioRecorder();
    await _start();
  }

  Widget _errorNotice(BuildContext context) {
    final colors = context.pbhColors;
    final permission = _error!.startsWith('Permita o microfone');
    final saving = _error!.contains('salvar a gravação');
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.orange.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: colors.orange.withValues(alpha: .22),
                    ),
                  ),
                  child: Icon(
                    saving ? Icons.mic_none_rounded : Icons.mic_off_rounded,
                    color: colors.orange,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                permission
                    ? 'Permita o microfone'
                    : saving
                    ? 'Vamos gravar novamente?'
                    : 'Microfone indisponível',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                permission
                    ? 'Para enviar sua mensagem de voz, o PBH precisa acessar o microfone.'
                    : saving
                    ? 'Não conseguimos preparar esse áudio. Faça uma nova gravação para continuar.'
                    : 'Não conseguimos acessar seu microfone agora. Confira se ele está conectado e disponível.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.background.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      saving ? Icons.refresh_rounded : Icons.tune_rounded,
                      size: 20,
                      color: colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        saving
                            ? 'Toque em tentar novamente para começar outra gravação.'
                            : kIsWeb
                            ? 'Na barra de endereço, abra as permissões deste site e libere o microfone. Se ele estiver em uso, feche a outra chamada ou gravação.'
                            : 'Nas configurações do celular, abra PBH Oficial → Permissões → Microfone e libere o acesso.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Até 2 minutos · Exclusão após 7 dias',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _retry,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.orange,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Tentar novamente',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) unawaited(_finish());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _limit?.cancel();
    unawaited(
      _recorder
          .cancel()
          .whenComplete(_recorder.dispose)
          .catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _errorNotice(context);
    final seconds = _watch.elapsed.inSeconds.clamp(0, 120);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _voice == null ? 'Mensagem de voz' : 'Ouça antes de enviar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            if (_voice != null)
              ChatAudioPlayer(
                load: () async => _voice!.bytes,
                durationMs: _voice!.durationMs,
                format: _voice!.format,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: context.pbhColors.orange),
                  const SizedBox(width: 12),
                  Text(
                    _busy
                        ? 'Preparando microfone…'
                        : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} / 2:00',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            const Text(
              'Até 2 minutos. O áudio desaparece após 7 dias.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_recording)
              FilledButton.icon(
                onPressed: _busy ? null : _finish,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Parar gravação'),
              ),
            if (_voice != null)
              FilledButton.icon(
                onPressed: () {
                  unawaited(ChatAudioPlayback.pauseAll());
                  Navigator.pop(context, _voice);
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Enviar áudio'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_voice == null ? 'Cancelar' : 'Descartar gravação'),
            ),
          ],
        ),
      ),
    );
  }
}
