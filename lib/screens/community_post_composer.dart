import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' as selector;
import '../models/community_photo.dart';
import '../models/community_topics.dart';
import '../services/community_service.dart';
import '../widgets/profile_cover_media.dart';

class CommunityPostComposer extends StatefulWidget {
  const CommunityPostComposer({
    super.key,
    required this.service,
    this.prompt,
    this.initialTopic,
    this.pickPhotos,
    this.pickOnOpen = false,
  });
  final bool pickOnOpen;
  final CommunityService service;
  final String? prompt, initialTopic;
  final Future<List<CommunityPhoto>> Function(int limit)? pickPhotos;
  @override
  State<CommunityPostComposer> createState() => _CommunityPostComposerState();
}

class _CommunityPostComposerState extends State<CommunityPostComposer> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(
    text: widget.prompt == null ? '' : '${widget.prompt}\n\n',
  );
  final _tag = TextEditingController();
  final _photos = <CommunityPhoto>[];
  final _draftId = CommunityService.newPostId();
  late String _topic = communityTopics.containsKey(widget.initialTopic)
      ? widget.initialTopic!
      : communityTopics.keys.first;
  bool _busy = false, _picking = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.pickOnOpen)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pick();
      });
  }

  @override
  void dispose() {
    _text.dispose();
    _tag.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy || _picking || _photos.length >= CommunityPhoto.maxCount) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final limit = CommunityPhoto.maxCount - _photos.length;
      List<CommunityPhoto> added;
      if (widget.pickPhotos != null) {
        added = await widget.pickPhotos!(limit);
      } else {
        final picker = ImagePicker();
        final files = <XFile>[];
        if (limit == 1) {
          final file = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 80,
            requestFullMetadata: false,
          );
          if (file != null) files.add(file);
        } else {
          files.addAll(
            await picker.pickMultiImage(
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 80,
              limit: limit,
              requestFullMetadata: false,
            ),
          );
        }
        added = [];
        for (final file in files.take(limit)) {
          if (await file.length() > CommunityPhoto.maxBytes)
            throw ArgumentError('Cada foto deve ter até 5 MB.');
          added.add(CommunityPhoto(await file.readAsBytes()));
        }
      }
      if (mounted) setState(() => _photos.addAll(added.take(limit)));
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is ArgumentError
              ? error.message.toString()
              : 'Não foi possível abrir as fotos. Tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _publish() async {
    if (_busy || _picking || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.createPost(
        _text.text,
        achievementTag: _tag.text,
        topic: _topic,
        photos: List.of(_photos),
        draftId: _draftId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível publicar. Seu relato e suas fotos continuam aqui. Confira a conexão e tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickOriginal(bool video, {bool html = false}) async {
    if (_busy || _picking || _photos.length >= CommunityPhoto.maxCount) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await selector.openFile(
        acceptedTypeGroups: [
          selector.XTypeGroup(
            label: html
                ? 'Arte HTML'
                : video
                ? 'Vídeo'
                : 'GIF',
            extensions: html
                ? ['html', 'htm']
                : video
                ? ['mp4', 'webm']
                : ['gif'],
            mimeTypes: html
                ? ['text/html', 'text/plain']
                : video
                ? ['video/mp4', 'video/webm']
                : ['image/gif'],
            uniformTypeIdentifiers: html
                ? ['public.html']
                : video
                ? ['public.movie']
                : ['com.compuserve.gif'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() >
          (html
              ? CommunityPhoto.maxBytes
              : video
              ? CommunityPhoto.maxVideoBytes
              : CommunityPhoto.maxGifBytes)) {
        throw ArgumentError(
          html
              ? 'O HTML deve ter até 5 MB.'
              : video
              ? 'O vídeo deve ter até 25 MB.'
              : 'O GIF deve ter até 10 MB.',
        );
      }
      final media = CommunityPhoto(await file.readAsBytes());
      if (html
          ? media.extension != 'html'
          : media.isVideo != video || (!video && media.extension != 'gif'))
        throw ArgumentError('Formato de arquivo inválido.');
      if (mounted) setState(() => _photos.add(media));
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is ArgumentError
              ? error.message.toString()
              : 'Não foi possível abrir o arquivo.',
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _close() async {
    if (_busy || _picking) return;
    final changed =
        _photos.isNotEmpty ||
        _tag.text.isNotEmpty ||
        _text.text.trim() != (widget.prompt ?? '').trim();
    final leave =
        !changed ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Descartar publicação?'),
                content: const Text(
                  'Seu relato e as fotos ainda não foram publicados.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Continuar escrevendo'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Descartar'),
                  ),
                ],
              ),
            ) ==
            true;
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Compartilhe sua jornada'),
        leading: IconButton(
          tooltip: 'Fechar publicação',
          onPressed: _busy || _picking ? null : _close,
          icon: const Icon(Icons.close),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: _busy || _picking ? null : _publish,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_busy ? 'Publicando…' : 'Publicar na comunidade'),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Relatos, aprendizados e pequenas vitórias fazem parte da comunidade.',
              ),
              const SizedBox(height: 12),
              const Text(
                'O texto e as fotos ficam visíveis na comunidade, inclusive para visitantes. Seu nome e sua foto seguem as configurações de privacidade.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _text,
                enabled: !_busy,
                minLines: 4,
                maxLines: 10,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Como está sendo sua jornada? Conte para a comunidade…',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escreva seu relato antes de publicar.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _topic,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assunto'),
                items: [
                  for (final topic in communityTopics.entries)
                    DropdownMenuItem(
                      value: topic.key,
                      child: Text(topic.value),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _topic = value);
                      },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy || _picking || _photos.length == 4
                    ? null
                    : _pick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _picking
                      ? 'Abrindo fotos…'
                      : 'Adicionar fotos (${_photos.length}/4)',
                ),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _busy || _picking || _photos.length >= 4
                        ? null
                        : () => _pickOriginal(false),
                    icon: const Icon(Icons.gif_box_outlined),
                    label: const Text('GIF'),
                  ),
                  TextButton.icon(
                    onPressed: _busy || _picking || _photos.length >= 4
                        ? null
                        : () => _pickOriginal(true),
                    icon: const Icon(Icons.video_library_outlined),
                    label: const Text('Vídeo'),
                  ),
                  TextButton.icon(
                    onPressed: _busy || _picking || _photos.length >= 4
                        ? null
                        : () => _pickOriginal(false, html: true),
                    icon: const Icon(Icons.code),
                    label: const Text('HTML'),
                  ),
                ],
              ),
              const Text(
                'Até 4 anexos: fotos e HTML 5 MB, GIFs 10 MB e vídeos MP4/WebM 25 MB cada. HTML deve incluir seus próprios recursos; links externos não carregam.',
              ),
              if (_photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _photos.length; i++)
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _photos[i].isVideo
                                    ? const ColoredBox(
                                        color: Colors.black,
                                        child: Center(
                                          child: Icon(
                                            Icons.play_circle_outline,
                                            size: 44,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : _photos[i].extension == 'html'
                                    ? ProfileCoverMedia(bytes: _photos[i].bytes)
                                    : Image.memory(
                                        _photos[i].bytes,
                                        fit: BoxFit.cover,
                                        cacheWidth: 240,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                      ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton.filled(
                                  tooltip: _photos[i].isVideo
                                      ? 'Remover vídeo ${i + 1}'
                                      : 'Remover foto ${i + 1}',
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                            setState(() => _photos.removeAt(i)),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Adicionar uma conquista (opcional)'),
                children: [
                  TextField(
                    controller: _tag,
                    enabled: !_busy,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      hintText: 'Uma conquista que você quer compartilhar',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
