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
    this.returnFraming = false,
  });
  final bool returnFraming;
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
  double _sourceRatio = 1;
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
    try {
      final codec = await ui.instantiateImageCodec(
        widget.bytes,
        targetWidth: 1600,
      );
      try {
        final frame = await codec.getNextFrame();
        _sourceRatio = frame.image.width / frame.image.height;
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
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
      if (widget.returnFraming) {
        final size = box.size;
        final width = _sourceRatio > widget.aspectRatio
            ? size.height * _sourceRatio
            : size.width;
        final height = width / _sourceRatio;
        final inverse = Matrix4.inverted(_transform.value);
        final origin = MatrixUtils.transformPoint(inverse, Offset.zero);
        final end = MatrixUtils.transformPoint(
          inverse,
          Offset(size.width, size.height),
        );
        Navigator.pop(context, <double>[
          (origin.dx / width).clamp(0, 1).toDouble(),
          (origin.dy / height).clamp(0, 1).toDouble(),
          ((end.dx - origin.dx) / width).clamp(.001, 1).toDouble(),
          ((end.dy - origin.dy) / height).clamp(.001, 1).toDouble(),
        ]);
        return;
      }
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = _sourceRatio > widget.aspectRatio
                                ? constraints.maxHeight * _sourceRatio
                                : constraints.maxWidth;
                            final height = width / _sourceRatio;
                            return InteractiveViewer(
                              constrained: false,
                              alignment: Alignment.topLeft,
                              transformationController: _transform,
                              minScale: 1,
                              maxScale: 4,
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: Image(
                                  image: _image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            );
                          },
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
