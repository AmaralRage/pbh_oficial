import '../widgets/community_mention_suggestions.dart';
import '../widgets/community_framed_image.dart';
import 'profile_image_cropper.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' as selector;
import '../models/community_photo.dart';
import '../models/community_topics.dart';
import '../services/community_service.dart';
import '../widgets/profile_cover_media.dart';
import '../services/community_draft_store.dart';
import '../services/community_photo_preparation.dart';

class CommunityPostComposer extends StatefulWidget {
  const CommunityPostComposer({
    super.key,
    required this.service,
    this.prompt,
    this.initialTopic,
    this.pickPhotos,
    this.pickOnOpen = false,
    this.draftStore,
  });
  final bool pickOnOpen;
  final CommunityDraftStore? draftStore;
  final CommunityService service;
  final String? prompt, initialTopic;
  final Future<List<CommunityPhoto>> Function(int limit)? pickPhotos;
  @override
  State<CommunityPostComposer> createState() => _CommunityPostComposerState();
}

class _CommunityPostComposerState extends State<CommunityPostComposer>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(
    text: widget.prompt == null ? '' : '${widget.prompt}\n\n',
  );
  final _tag = TextEditingController();
  final _mentionFocus = FocusNode();
  final _photos = <CommunityPhoto>[];
  String _draftId = CommunityService.newPostId();
  late final _account = widget.service.currentUserId;
  late final _drafts = widget.draftStore ?? CommunityDraftStore();
  Timer? _autosave;
  StreamSubscription? _auth;
  Future<void> _writes = Future.value();
  bool _restoring = true, _finalizing = false, _published = false;
  String? _draftMessage;
  late String _topic = communityTopics.containsKey(widget.initialTopic)
      ? widget.initialTopic!
      : communityTopics.keys.first;
  bool _busy = false, _picking = false;
  int _uploaded = 0, _uploadTotal = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_scheduleDraft);
    _tag.addListener(_scheduleDraft);
    _auth = widget.service.authChanges.listen((_) {
      if (mounted && widget.service.currentUserId != _account)
        Navigator.of(context).pop();
    });
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      final draft = _account == null ? null : await _drafts.load(_account);
      if (!mounted) return;
      if (draft != null) {
        _draftId = draft.id;
        _text.text = draft.text;
        _tag.text = draft.tag;
        _topic = communityTopics.containsKey(draft.topic)
            ? draft.topic
            : communityTopics.keys.first;
        _photos.addAll(draft.photos);
        _draftMessage = 'Rascunho recuperado deste aparelho.';
      }
    } catch (_) {
      if (mounted)
        _draftMessage = 'Não foi possível recuperar o rascunho neste aparelho.';
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
        if (widget.pickOnOpen)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _pick();
          });
      }
    }
  }

  void _scheduleDraft() {
    if (_restoring || _finalizing || _account == null) return;
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 600), () => _persistDraft());
  }

  Future<bool> _persistDraft() async {
    if (_account == null) return true;
    if (_restoring || widget.service.currentUserId != _account) return false;
    final snapshot = CommunityDraft(
      id: _draftId,
      text: _text.text,
      tag: _tag.text,
      topic: _topic,
      photos: List.of(_photos),
    );
    var saved = false;
    _writes = _writes.then((_) async {
      try {
        await _drafts.save(_account, snapshot);
        saved = true;
        if (mounted)
          setState(() => _draftMessage = 'Rascunho salvo neste aparelho.');
      } catch (_) {
        if (mounted)
          setState(
            () => _draftMessage =
                'Não foi possível salvar o rascunho. Confira o espaço do aparelho e tente novamente.',
          );
      }
    });
    await _writes;
    return saved;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_finalizing) {
      _autosave?.cancel();
      unawaited(_persistDraft());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    _auth?.cancel();
    _mentionFocus.dispose();
    _text.dispose();
    _tag.dispose();
    super.dispose();
  }

  Future<void> _cropPhoto(int index) async {
    if (_busy || _picking) return;
    final photo = _photos[index];
    setState(() => _picking = true);
    try {
      final framing = await Navigator.of(context).push<List<double>>(
        MaterialPageRoute(
          builder: (_) => ProfileImageCropper(
            bytes: photo.bytes,
            aspectRatio: _photos.length == 1 ? 4 / 5 : 1,
            title: 'Enquadrar foto',
            returnFraming: true,
          ),
        ),
      );
      if (!mounted || framing == null) return;
      setState(
        () => _photos[index] = CommunityPhoto(photo.bytes, framing: framing),
      );
      _scheduleDraft();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
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
          if (await file.length() > CommunityPhoto.maxVideoBytes)
            throw ArgumentError('Cada arquivo deve ter até 25 MB.');
          added.add(await prepareCommunityPhoto(await file.readAsBytes()));
        }
      }
      if (mounted) setState(() => _photos.addAll(added.take(limit)));
      _scheduleDraft();
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
    if (_busy ||
        _picking ||
        _restoring ||
        _finalizing ||
        !_form.currentState!.validate())
      return;
    if (widget.service.currentUserId != _account) {
      setState(() => _error = 'A conta mudou. Reabra a publicação.');
      return;
    }
    _finalizing = true;
    _uploaded = 0;
    _uploadTotal = _photos.length;
    _autosave?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    await _writes;
    if (!mounted) return;
    try {
      await widget.service.createPost(
        _text.text,
        achievementTag: _tag.text,
        topic: _topic,
        photos: List.of(_photos),
        draftId: _draftId,
        onUploadProgress: (done, total) {
          if (mounted)
            setState(() {
              _uploaded = done;
              _uploadTotal = total;
            });
        },
      );
      if (_account != null) {
        try {
          await _drafts.clear(_account);
        } catch (_) {}
      }
      _published = true;
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível publicar. Seu relato e suas fotos continuam aqui. Confira a conexão e tente novamente.',
        );
    } finally {
      if (!_published) {
        _finalizing = false;
        if (mounted) _scheduleDraft();
      }
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
      _scheduleDraft();
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
    if (!changed) {
      _finalizing = true;
      _autosave?.cancel();
      if (mounted) Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _account == null ? 'Descartar publicação?' : 'Guardar publicação?',
        ),
        content: const Text(
          'Seu relato e os anexos ainda não foram publicados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar escrevendo'),
          ),
          if (_account != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Salvar rascunho e sair'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    _autosave?.cancel();
    if (choice == 'save' && !await _persistDraft()) return;
    _finalizing = true;
    await _writes;
    if (choice == 'discard' && _account != null) {
      try {
        await _drafts.clear(_account);
      } catch (_) {
        _finalizing = false;
        if (mounted)
          setState(
            () =>
                _error = 'Não foi possível apagar o rascunho. Tente novamente.',
          );
        return;
      }
    }
    if (mounted) Navigator.pop(context);
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
              if (_busy && _uploadTotal > 0) ...[
                Text(
                  _uploaded == _uploadTotal
                      ? 'Finalizando publicação…'
                      : 'Anexos enviados: $_uploaded de $_uploadTotal',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _uploaded == _uploadTotal
                      ? null
                      : _uploaded / _uploadTotal,
                ),
                const SizedBox(height: 12),
              ],
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
      body: _restoring
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_draftMessage != null)
                      Text(
                        _draftMessage!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                      focusNode: _mentionFocus,
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Escreva seu relato antes de publicar.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    CommunityMentionSuggestions(
                      controller: _text,
                      focusNode: _mentionFocus,
                      service: widget.service,
                    ),
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
                              if (value != null) {
                                setState(() => _topic = value);
                                _scheduleDraft();
                              }
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
                                height: _photos.length == 1 ? 150 : 120,
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
                                          ? ProfileCoverMedia(
                                              bytes: _photos[i].bytes,
                                            )
                                          : CommunityFramedImage(
                                              framing: _photos[i].framing,
                                              child: Image.memory(
                                                _photos[i].bytes,
                                                fit: _photos[i].framing == null
                                                    ? BoxFit.cover
                                                    : BoxFit.fill,
                                                cacheWidth: 240,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                    ),
                                              ),
                                            ),
                                    ),
                                    if (const [
                                      'jpg',
                                      'png',
                                      'webp',
                                    ].contains(_photos[i].extension))
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        child: IconButton.filled(
                                          tooltip: 'Enquadrar foto',
                                          onPressed: _busy || _picking
                                              ? null
                                              : () => _cropPhoto(i),
                                          icon: const Icon(
                                            Icons.crop,
                                            size: 18,
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
                                            : () {
                                                setState(
                                                  () => _photos.removeAt(i),
                                                );
                                                _scheduleDraft();
                                              },
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
                            hintText:
                                'Uma conquista que você quer compartilhar',
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
