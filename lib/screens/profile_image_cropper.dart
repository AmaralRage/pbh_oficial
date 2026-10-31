import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ProfileImageCropper extends StatefulWidget {
  const ProfileImageCropper({
    super.key,
    required this.bytes,
    required this.aspectRatio,
    required this.title,
  });
  final Uint8List bytes;
  final double aspectRatio;
  final String title;
  @override
  State<ProfileImageCropper> createState() => _ProfileImageCropperState();
}

class _ProfileImageCropperState extends State<ProfileImageCropper> {
  final _boundary = GlobalKey();
  final _transform = TransformationController();
  bool _ready = false, _saving = false, _failed = false;
  late final ImageProvider _image = ResizeImage(
    MemoryImage(widget.bytes),
    width: 1600,
    height: 3200,
    policy: ResizeImagePolicy.fit,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready && !_failed) _prepare();
  }

  Future<void> _prepare() async {
    var failed = false;
    await precacheImage(
      _image,
      context,
      onError: (_, __) {
        failed = true;
      },
    );
    if (mounted)
      setState(() {
        _failed = failed;
        _ready = !failed;
      });
  }

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final box =
          _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var ratio = (1600 / box.size.width).clamp(1.0, 3.0);
      Uint8List? result;
      for (var attempt = 0; attempt < 5; attempt++) {
        final image = await box.toImage(pixelRatio: ratio);
        try {
          result = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))?.buffer.asUint8List();
        } finally {
          image.dispose();
        }
        if (result != null && result.length <= 5 * 1024 * 1024) break;
        ratio *= .7;
      }
      if (result == null || result.length > 5 * 1024 * 1024)
        throw StateError('Imagem muito grande.');
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível recortar a imagem. Tente novamente.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Arraste para posicionar. Use dois dedos ou a roda do mouse para ajustar o zoom.',
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: RepaintBoundary(
                    key: _boundary,
                    child: ClipRect(
                      child: ColoredBox(
                        color: Colors.transparent,
                        child: InteractiveViewer(
                          transformationController: _transform,
                          minScale: 1,
                          maxScale: 4,
                          child: SizedBox.expand(
                            child: Image(
                              image: _image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_failed) const Text('Não foi possível abrir esta imagem.'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Restaurar recorte',
                  onPressed: _saving
                      ? null
                      : () => _transform.value = Matrix4.identity(),
                  icon: const Icon(Icons.restart_alt),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !_ready || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Preparando…' : 'Usar recorte'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
