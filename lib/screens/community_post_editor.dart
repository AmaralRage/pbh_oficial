import '../widgets/community_mention_suggestions.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' as files;
import 'package:http/http.dart' as http;
import '../models/community_post_model.dart';
import '../models/community_photo.dart';
import '../services/community_service.dart';
import '../widgets/community_framed_image.dart';
import '../widgets/community_photo_gallery.dart';
import 'profile_image_cropper.dart';
import '../services/community_photo_preparation.dart';

class _Attachment {
  _Attachment({this.path, this.url, this.photo, this.framing});
  final String? path, url;
  final CommunityPhoto? photo;
  List<double>? framing;
  String get extension => photo?.extension ?? path!.split('.').last;
  bool get canFrame => ['jpg', 'png', 'webp'].contains(extension);
}

class CommunityPostEditor extends StatefulWidget {
  const CommunityPostEditor({
    super.key,
    required this.post,
    required this.service,
  });
  final CommunityPostModel post;
  final CommunityService service;
  @override
  State<CommunityPostEditor> createState() => _CommunityPostEditorState();
}

class _CommunityPostEditorState extends State<CommunityPostEditor> {
  late final _text = TextEditingController(text: widget.post.content);
  final _mentionFocus = FocusNode();
  late final _account = widget.service.currentUserId;
  late final _attachments = [
    for (var i = 0; i < widget.post.imagePaths.length; i++)
      _Attachment(
        path: widget.post.imagePaths[i],
        url: i < widget.post.imageUrls.length ? widget.post.imageUrls[i] : '',
        framing:
            i < widget.post.imageFramings.length &&
                widget.post.imageFramings[i] is List
            ? (widget.post.imageFramings[i] as List)
                  .map((n) => (n as num).toDouble())
                  .toList()
            : null,
      ),
  ];
  bool _busy = false, _picking = false, _dirty = false;
  int _uploaded = 0, _uploadTotal = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (!_dirty && _text.text != widget.post.content)
        setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    _mentionFocus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _resetAspect(int oldCount) {
    if ((oldCount == 1) != (_attachments.length == 1)) {
      for (final a in _attachments) {
        a.framing = null;
      }
    }
    _dirty = true;
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final selected = await files.openFiles(
        acceptedTypeGroups: [
          const files.XTypeGroup(
            label: 'Fotos, GIFs, vídeos e arte HTML',
            extensions: [
              'jpg',
              'jpeg',
              'png',
              'webp',
              'gif',
              'mp4',
              'webm',
              'html',
            ],
          ),
        ],
      );
      final added = <_Attachment>[];
      for (final f in selected.take(4 - _attachments.length)) {
        if (await f.length() > CommunityPhoto.maxVideoBytes)
          throw ArgumentError('O limite por anexo é de 25 MB.');
        added.add(
          _Attachment(
            photo: await prepareCommunityPhoto(await f.readAsBytes()),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        final count = _attachments.length;
        _attachments.addAll(added);
        if (added.isNotEmpty) _resetAspect(count);
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Confira o formato e o tamanho dos anexos. Fotos: 5 MB; GIFs: 10 MB; vídeos: 25 MB.',
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _frame(_Attachment attachment) async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      Uint8List bytes;
      if (attachment.photo != null) {
        bytes = attachment.photo!.bytes;
      } else {
        final response = await http
            .get(Uri.parse(attachment.url!))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 ||
            response.bodyBytes.length > CommunityPhoto.maxBytes)
          throw StateError('Imagem indisponível.');
        bytes = response.bodyBytes;
      }
      if (!mounted) return;
      final result = await Navigator.push<List<double>>(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileImageCropper(
            bytes: bytes,
            aspectRatio: _attachments.length == 1 ? 4 / 5 : 1,
            title: 'Enquadrar prévia',
            returnFraming: true,
          ),
        ),
      );
      if (mounted && result != null)
        setState(() {
          attachment.framing = result;
          _dirty = true;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível abrir a imagem. Reabra o editor para renovar o acesso.',
        );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _picking) return;
    if (_text.text.trim().isEmpty || _text.text.trim().length > 2000) {
      setState(() => _error = 'Escreva de 1 a 2000 caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _uploaded = 0;
      _uploadTotal = _attachments.where((a) => a.photo != null).length;
      _error = null;
    });
    try {
      if (_account != widget.service.currentUserId)
        throw StateError('A conta mudou.');
      await widget.service.editPublication(
        widget.post,
        _text.text,
        [for (final a in _attachments) a.path],
        [for (final a in _attachments) a.photo],
        [for (final a in _attachments) a.framing],
        onUploadProgress: (done, total) {
          if (mounted)
            setState(() {
              _uploaded = done;
              _uploadTotal = total;
            });
        },
      );
      if (mounted && _account == widget.service.currentUserId) {
        setState(() {
          _busy = false;
          _dirty = false;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        setState(
          () => _error = _account != widget.service.currentUserId
              ? 'A conta mudou. Reabra o editor na conta do autor.'
              : e.toString().contains('40001')
              ? 'A publicação mudou. Volte, atualize o feed e reabra o editor.'
              : 'Não foi possível salvar. Suas alterações continuam aqui. Confira a conexão e tente novamente.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('A publicação atual será mantida.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (mounted && discard == true) {
      setState(() => _dirty = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_picking && !_dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy && !_picking) _leave();
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Editar publicação')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _text,
            focusNode: _mentionFocus,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            enabled: !_busy && !_picking,
            onChanged: (_) => setState(() => _dirty = true),
            decoration: const InputDecoration(labelText: 'Seu relato'),
          ),
          const SizedBox(height: 16),
          CommunityMentionSuggestions(
            controller: _text,
            focusNode: _mentionFocus,
            service: widget.service,
          ),
          const Text(
            'Anexos e enquadramento',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'O enquadramento muda só a prévia. Ao abrir a foto, ela continua inteira.',
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _attachments.length; i++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 180,
                      width: double.infinity,
                      child:
                          [
                            'html',
                            'mp4',
                            'webm',
                          ].contains(_attachments[i].extension)
                          ? Icon(
                              _attachments[i].extension == 'html'
                                  ? Icons.code
                                  : Icons.play_circle_outline,
                              size: 48,
                            )
                          : CommunityFramedImage(
                              framing: _attachments[i].framing,
                              child: _attachments[i].photo != null
                                  ? Image.memory(
                                      _attachments[i].photo!.bytes,
                                      cacheWidth: 720,
                                      fit: _attachments[i].framing == null
                                          ? BoxFit.cover
                                          : BoxFit.fill,
                                    )
                                  : CommunityPhotoGallery.photo(
                                      _attachments[i].url ?? '',
                                      cacheWidth: 720,
                                      fit: _attachments[i].framing == null
                                          ? BoxFit.cover
                                          : BoxFit.fill,
                                    ),
                            ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_attachments[i].canFrame)
                          TextButton.icon(
                            onPressed: _busy || _picking
                                ? null
                                : () => _frame(_attachments[i]),
                            icon: const Icon(Icons.crop),
                            label: const Text('Enquadrar'),
                          ),
                        IconButton(
                          tooltip: 'Remover anexo',
                          onPressed: _busy || _picking
                              ? null
                              : () => setState(() {
                                  final count = _attachments.length;
                                  _attachments.removeAt(i);
                                  _resetAspect(count);
                                }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _busy || _picking || _attachments.length >= 4
                ? null
                : _pick,
            icon: const Icon(Icons.attach_file),
            label: Text('Adicionar anexos (${_attachments.length}/4)'),
          ),
          if (_picking || _busy) const LinearProgressIndicator(),
          if (_busy && _uploadTotal > 0)
            Text(
              _uploaded == _uploadTotal
                  ? 'Finalizando alterações…'
                  : 'Anexos enviados: $_uploaded de $_uploadTotal',
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || _picking ? null : _save,
            child: Text(_busy ? 'Salvando…' : 'Salvar alterações'),
          ),
        ],
      ),
    ),
  );
}
