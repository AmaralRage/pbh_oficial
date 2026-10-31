import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'profile_cover_media.dart';

class CommunityPhotoGallery extends StatelessWidget {
  const CommunityPhotoGallery({
    super.key,
    required this.urls,
    this.paths = const [],
    this.onRefresh,
  });
  final List<String> urls;
  final List<String> paths;
  bool isVideo(int i) =>
      i < paths.length &&
      RegExp(r'\.(mp4|webm)$', caseSensitive: false).hasMatch(paths[i]);
  Widget preview(int i) => isVideo(i)
      ? const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 56,
            ),
          ),
        )
      : i < paths.length && paths[i].endsWith('.html')
      ? ProfileCoverMedia(url: urls[i], communityAttachment: true)
      : photo(urls[i]);
  final VoidCallback? onRefresh;
  static Widget photo(String url, {BoxFit fit = BoxFit.cover}) => url.isEmpty
      ? const Center(child: Icon(Icons.image_not_supported_outlined))
      : Image.network(
          url,
          fit: fit,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        );
  void _open(BuildContext context, int index) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PhotoViewer(urls: urls, paths: paths, initial: index),
      fullscreenDialog: true,
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      if (urls.every((url) => url.isEmpty))
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Recarregar anexos'),
        ),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: urls.length == 1
            ? AspectRatio(
                aspectRatio: 4 / 3,
                child: InkWell(
                  onTap: () => _open(context, 0),
                  child: preview(0),
                ),
              )
            : GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (var i = 0; i < urls.length; i++)
                    Semantics(
                      label: isVideo(i)
                          ? 'Abrir vídeo ${i + 1}'
                          : 'Ampliar foto ${i + 1}',
                      button: true,
                      child: InkWell(
                        onTap: () => _open(context, i),
                        child: preview(i),
                      ),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Text(
              paths.any((path) => path.endsWith('.html'))
                  ? 'Arte HTML animada · toque para ampliar'
                  : 'Toque para abrir · ${urls.length} ${urls.length == 1 ? 'anexo' : 'anexos'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (onRefresh != null && urls.any((url) => url.isNotEmpty))
            IconButton(
              tooltip: 'Recarregar anexos',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
            ),
        ],
      ),
    ],
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.urls,
    required this.paths,
    required this.initial,
  });
  final List<String> urls;
  final List<String> paths;
  final int initial;
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('Anexo ${_index + 1} de ${widget.urls.length}'),
    ),
    body: SafeArea(
      child: PageView.builder(
        controller: _pages,
        itemCount: widget.urls.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (_, i) =>
            i < widget.paths.length &&
                RegExp(
                  r'\.(mp4|webm)$',
                  caseSensitive: false,
                ).hasMatch(widget.paths[i])
            ? CommunityVideoPlayer(url: widget.urls[i], active: i == _index)
            : InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: SizedBox.expand(
                  child:
                      i < widget.paths.length &&
                          widget.paths[i].endsWith('.html')
                      ? ProfileCoverMedia(
                          url: widget.urls[i],
                          communityAttachment: true,
                        )
                      : CommunityPhotoGallery.photo(
                          widget.urls[i],
                          fit: BoxFit.contain,
                        ),
                ),
              ),
      ),
    ),
  );
}

class CommunityVideoPlayer extends StatefulWidget {
  const CommunityVideoPlayer({
    super.key,
    required this.url,
    required this.active,
  });
  final String url;
  final bool active;
  @override
  State<CommunityVideoPlayer> createState() => _CommunityVideoPlayerState();
}

class _CommunityVideoPlayerState extends State<CommunityVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _load();
  }

  Future<void> _load() async {
    if (_controller != null || _loading) return;
    _loading = true;
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _controller = controller;
      await controller.initialize().timeout(const Duration(seconds: 25));
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível reproduzir este vídeo. Recarregue o anexo ou use MP4 com codec H.264.',
        );
    } finally {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(covariant CommunityVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _controller?.pause();
    } else {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  @override
  void deactivate() {
    _controller?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.white)),
        ),
      );
    if (controller == null || !controller.value.isInitialized)
      return const Center(child: CircularProgressIndicator());
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          if (value.hasError)
            const Text(
              'Falha na reprodução. Recarregue o anexo.',
              style: TextStyle(color: Colors.white),
            ),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.all(16),
          ),
          IconButton(
            tooltip: value.isPlaying ? 'Pausar vídeo' : 'Reproduzir vídeo',
            color: Colors.white,
            onPressed: !widget.active
                ? null
                : () {
                    value.isPlaying ? controller.pause() : controller.play();
                  },
            icon: Icon(
              value.isPlaying ? Icons.pause_circle : Icons.play_circle,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }
}
