import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/lesson_media.dart';

class LessonMediaCard extends StatefulWidget {
  const LessonMediaCard({super.key, required this.media, this.openLink});
  final LessonMedia media;
  final Future<bool> Function(Uri)? openLink;
  @override
  State<LessonMediaCard> createState() => _LessonMediaCardState();
}

class _LessonMediaCardState extends State<LessonMediaCard> {
  bool _opening = false;
  String? _failedUrl;
  Future<void> _open(String url) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failedUrl = null;
    });
    try {
      if (!LessonMedia.isWebUrl(url)) {
        throw const FormatException('Link inválido');
      }
      final uri = Uri.parse(url);
      final opened = widget.openLink != null
          ? await widget.openLink!(uri)
          : await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_blank',
            );
      if (!opened) throw StateError('Não foi possível abrir o link');
    } catch (_) {
      if (mounted) setState(() => _failedUrl = url);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _failedUrl!));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link copiado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível copiar o link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final podcast = media.kind == LessonMediaKind.podcast;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Abrir ${media.title}',
            child: InkWell(
              onTap: _opening ? null : () => _open(media.url),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: context.pbhColors.backgroundElevated,
                      child:
                          media.thumbnailUrl != null &&
                              LessonMedia.isWebUrl(media.thumbnailUrl!)
                          ? Image.network(
                              media.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(
                                  podcast
                                      ? Icons.podcasts
                                      : Icons.video_library_outlined,
                                  size: 56,
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                podcast
                                    ? Icons.podcasts
                                    : Icons.video_library_outlined,
                                size: 56,
                              ),
                            ),
                    ),
                    const ColoredBox(color: Color(0x44000000)),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xCC000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  podcast ? 'PODCAST EM PORTUGUÊS' : 'VÍDEO EM PORTUGUÊS',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(media.title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 6),
                Text(media.author, style: AppTextStyles.bodySmall),
                const SizedBox(height: 12),
                Text(media.summary, style: AppTextStyles.body),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _opening ? null : () => _open(media.url),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(
                    _opening
                        ? 'Abrindo…'
                        : podcast
                        ? 'Assistir episódio'
                        : 'Assistir vídeo',
                  ),
                ),
                if (media.audioUrl != null)
                  TextButton.icon(
                    onPressed: _opening ? null : () => _open(media.audioUrl!),
                    icon: const Icon(Icons.headphones),
                    label: const Text('Ouvir podcast'),
                  ),
                Text(
                  'Abre na plataforma do autor.',
                  style: AppTextStyles.bodySmall,
                ),
                if (_failedUrl != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Não foi possível abrir o conteúdo. Tente novamente ou copie o link.',
                  ),
                  TextButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar link'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
