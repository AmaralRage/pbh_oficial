import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/config/supabase_config.dart';
import '../services/profile_cover_document.dart';
import 'html_cover_renderer.dart';

/// The uploaded artwork stays below the independent profile ornaments.
class ProfileCoverMedia extends StatefulWidget {
  const ProfileCoverMedia({super.key, this.bytes, this.url});
  final Uint8List? bytes;
  final String? url;
  @override
  State<ProfileCoverMedia> createState() => _ProfileCoverMediaState();
}

class _ProfileCoverMediaState extends State<ProfileCoverMedia>
    with WidgetsBindingObserver {
  String? _source;
  String? _document;
  bool _reduced = false;
  bool _failed = false;
  bool _playing = false;
  bool _foreground = true;
  bool _scheduled = false;
  bool _enabled = false;
  int _generation = 0;
  ScrollPosition? _scroll;
  bool get _html => widget.bytes != null
      ? ProfileCoverDocument.looksLikeHtml(widget.bytes!)
      : ProfileCoverDocument.isHtmlUrl(widget.url);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _source = null;
    _document = null;
    _failed = false;
    if (!_html) return;
    try {
      Uint8List bytes;
      if (widget.bytes != null) {
        bytes = widget.bytes!;
      } else {
        final uri = Uri.parse(widget.url!);
        final origin = Uri.parse(SupabaseConfig.url);
        if (uri.origin != origin.origin ||
            !uri.path.startsWith('/storage/v1/object/public/profile-covers/'))
          throw const FormatException('Unsupported cover URL');
        final client = http.Client();
        try {
          final response = await client
              .send(http.Request('GET', uri)..followRedirects = false)
              .timeout(const Duration(seconds: 10));
          if (response.statusCode != 200 ||
              (response.contentLength ?? 0) > ProfileCoverDocument.maxBytes)
            throw const FormatException('Invalid cover response');
          final buffer = BytesBuilder(copy: false);
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 10),
          )) {
            if (buffer.length + chunk.length > ProfileCoverDocument.maxBytes)
              throw const FormatException('Cover too large');
            buffer.add(chunk);
          }
          bytes = buffer.takeBytes();
        } finally {
          client.close();
        }
      }
      final source = ProfileCoverDocument.decode(bytes);
      if (mounted && generation == _generation)
        setState(() {
          _source = source;
          _document = null;
        });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant ProfileCoverMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes || oldWidget.url != widget.url) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reduced) _document = null;
    _reduced = reduced;
    _enabled =
        !reduced &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_checkVisibility);
      _scroll = scroll;
      _scroll?.addListener(_checkVisibility);
    }
    _checkVisibility();
  }

  void _checkVisibility() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      final view = View.of(context);
      final visible =
          box is RenderBox &&
          box.attached &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).overlaps(
            Offset.zero & (view.physicalSize / view.devicePixelRatio),
          );
      final playing = _enabled && _foreground && visible;
      if (playing != _playing) setState(() => _playing = playing);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _playing) setState(() => _playing = false);
    _checkVisibility();
  }

  @override
  void dispose() {
    ++_generation;
    _scroll?.removeListener(_checkVisibility);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget failed() => const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white54),
    );
    if (_failed) return failed();
    if (_html) {
      if (_source == null) return const SizedBox.shrink();
      // Keep the document stable during play/pause to preserve animation state.
      _document ??= ProfileCoverDocument.wrap(
        _source!,
        playing: false,
        reducedMotion: _reduced,
      );
      return IgnorePointer(
        child: HtmlCoverRenderer(document: _document!, playing: _playing),
      );
    }
    final ImageProvider image = widget.bytes != null
        ? MemoryImage(widget.bytes!)
        : NetworkImage(widget.url!);
    if (_reduced)
      return IgnorePointer(child: _StillCoverImage(provider: image));
    return IgnorePointer(
      child: TickerMode(
        enabled: _playing,
        child: Image(
          image: image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => failed(),
        ),
      ),
    );
  }
}

/// Listen for one frame only, so reduced motion also freezes animated GIFs.
class _StillCoverImage extends StatefulWidget {
  const _StillCoverImage({required this.provider});
  final ImageProvider provider;
  @override
  State<_StillCoverImage> createState() => _StillCoverImageState();
}

class _StillCoverImageState extends State<_StillCoverImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _image;
  bool _failed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _StillCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) _resolve();
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
  }

  void _resolve() {
    final stream = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    if (_stream?.key == stream.key) return;
    _detach();
    _image?.dispose();
    _image = null;
    _failed = false;
    _stream = stream;
    _listener = ImageStreamListener(
      (image, _) {
        _detach();
        if (!mounted) return;
        setState(() {
          _image?.dispose();
          _image = image.clone();
        });
      },
      onError: (Object error, StackTrace? stack) {
        _detach();
        if (mounted) setState(() => _failed = true);
      },
    );
    stream.addListener(_listener!);
  }

  @override
  void dispose() {
    _detach();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _failed
      ? const Icon(Icons.broken_image_outlined, color: Colors.white54)
      : RawImage(image: _image?.image, fit: BoxFit.cover);
}
