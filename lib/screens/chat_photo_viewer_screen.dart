import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/photo_download_platform.dart' as platform;
import '../core/theme/app_colors.dart';

class ChatPhotoViewerScreen extends StatefulWidget {
  const ChatPhotoViewerScreen({
    super.key,
    required this.threadId,
    required this.message,
    required this.service,
    this.save,
    this.share,
  });
  final String threadId;
  final ChatMessage message;
  final ChatService service;
  final Future<bool> Function(Uint8List, String, String)? save;
  final Future<void> Function(Uint8List, String, Rect?)? share;
  @override
  State<ChatPhotoViewerScreen> createState() => _ChatPhotoViewerScreenState();
}

class _ChatPhotoViewerScreenState extends State<ChatPhotoViewerScreen> {
  final _transform = TransformationController();
  final _shareKey = GlobalKey();
  late final _account = widget.service.userId;
  StreamSubscription<AuthState>? _auth;
  Timer? _expiry;
  Uint8List? _bytes;
  bool _loading = true,
      _busy = false,
      _failed = false,
      _expired = false,
      _zoomed = false;
  Offset _doubleTap = Offset.zero;
  @override
  void initState() {
    super.initState();
    _transform.addListener(_zoomChanged);
    _auth = widget.service.client.auth.onAuthStateChange.listen((_) {
      if (mounted && widget.service.userId != _account) {
        setState(() {
          _clearBytes();
          _expired = true;
          _failed = true;
        });
        Navigator.maybePop(context);
      }
    });
    final remaining = widget.message.expiresAt.difference(DateTime.now());
    _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      _clearBytes();
      if (mounted)
        setState(() {
          _expired = true;
          _failed = true;
          _loading = false;
        });
    });
    _load();
  }

  void _clearBytes() {
    final bytes = _bytes;
    _bytes = null;
    if (bytes != null) unawaited(MemoryImage(bytes).evict());
  }

  bool get _allowed =>
      mounted &&
      widget.service.userId == _account &&
      !_expired &&
      widget.message.expiresAt.isAfter(DateTime.now());
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final bytes = await widget.service.photo(widget.threadId, widget.message);
      if (!_allowed) return;
      _clearBytes();
      setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _zoomChanged() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (mounted && zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _toggleZoom(Offset focus) {
    _transform.value = _zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translate(-focus.dx * 1.5, -focus.dy * 1.5)
            ..scale(2.5));
  }

  void _notice(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export(bool share) async {
    if (_busy || !_allowed || _bytes == null) return;
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    var verified = false;
    try {
      // Never export the signed URL; verify access and share only image bytes.
      final bytes = await widget.service.photo(widget.threadId, widget.message);
      if (!_allowed) return;
      verified = true;
      final name = 'pbh-foto-${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (share) {
        if (widget.share != null) {
          await widget.share!(bytes, name, origin);
        } else {
          final result = await Share.shareXFiles(
            [XFile.fromData(bytes, mimeType: 'image/jpeg', name: name)],
            fileNameOverrides: [name],
            sharePositionOrigin: origin,
          );
          if (result.status == ShareResultStatus.unavailable)
            _notice('Compartilhamento indisponível neste dispositivo.');
        }
      } else {
        final saved = await (widget.save ?? platform.savePhotoBytes)(
          bytes,
          name,
          'image/jpeg',
        );
        if (saved)
          _notice(kIsWeb ? 'Download solicitado ao navegador.' : 'Foto salva.');
      }
    } catch (_) {
      _notice(
        !verified
            ? 'Não foi possível acessar a foto. Ela pode ter expirado ou estar indisponível.'
            : share
            ? 'Não foi possível compartilhar a foto. Tente novamente.'
            : 'Não foi possível salvar a foto. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    unawaited(_auth?.cancel() ?? Future<void>.value());
    _clearBytes();
    _transform.removeListener(_zoomChanged);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _allowed && _bytes != null && !_loading && !_busy;
    final accent = context.pbhColors.orange;
    ButtonStyle actionStyle({bool highlighted = false}) => IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      iconSize: 21,
      backgroundColor: highlighted
          ? accent.withValues(alpha: .16)
          : Colors.white.withValues(alpha: .065),
      foregroundColor: highlighted
          ? accent
          : Colors.white.withValues(alpha: .9),
      disabledForegroundColor: Colors.white30,
      side: BorderSide(
        color: highlighted
            ? accent.withValues(alpha: .28)
            : Colors.white.withValues(alpha: .09),
      ),
      shape: const CircleBorder(),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _busy ? 'Aguarde…' : 'Foto',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        toolbarHeight: 68,
        actions: [
          IconButton(
            style: actionStyle(highlighted: _zoomed),
            tooltip: _zoomed ? 'Reduzir foto' : 'Ampliar foto',
            onPressed: enabled
                ? () => _toggleZoom(
                    Offset(
                      MediaQuery.sizeOf(context).width / 2,
                      MediaQuery.sizeOf(context).height / 2,
                    ),
                  )
                : null,
            icon: Icon(
              _zoomed ? Icons.zoom_out_rounded : Icons.zoom_in_rounded,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            style: actionStyle(),
            key: _shareKey,
            tooltip: 'Compartilhar foto',
            onPressed: enabled ? () => _export(true) : null,
            icon: const Icon(Icons.share_outlined),
          ),
          if (platform.photoDownloadSupported || widget.save != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                style: actionStyle(highlighted: true),
                tooltip: 'Salvar foto',
                onPressed: enabled ? () => _export(false) : null,
                icon: _busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: context.pbhColors.orange,
                ),
              )
            : _failed || _bytes == null || !_allowed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.image_not_supported_outlined,
                        size: 40,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Foto indisponível ou expirada.',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      if (!_expired)
                        TextButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente'),
                        ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onDoubleTapDown: (details) =>
                          _doubleTap = details.localPosition,
                      onDoubleTap: () => _toggleZoom(_doubleTap),
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 4,
                        child: Center(
                          child: Image.memory(
                            _bytes!,
                            fit: BoxFit.contain,
                            semanticLabel: 'Foto da conversa',
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.message.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Text(
                        widget.message.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
