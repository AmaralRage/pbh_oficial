import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/chat_navigation.dart';
import 'public_member_profile_screen.dart';
import '../services/community_service.dart';
import '../services/chat_local_store.dart';
import '../services/chat_image_preparation.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.threadId,
    this.initial,
    this.service,
    this.localStore,
  });
  final String threadId;
  final ChatThread? initial;
  final ChatService? service;
  final ChatLocalStore? localStore;
  @override
  State<ChatRoomScreen> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  late final _service = widget.service ?? ChatService();
  late final _account = _service.userId;
  late final _store = widget.localStore ?? ChatLocalStore();
  final _text = TextEditingController();
  final _messages = <ChatMessage>[];
  final _sendEntrances = <String>{};
  String _id = CommunityService.newPostId();
  String? _reply;
  Uint8List? _photo, _wallpaper;
  ChatThread? _thread;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  Timer? _events, _clock, _draftTimer;
  bool _loading = true,
      _sending = false,
      _more = true,
      _failed = false,
      _connected = true,
      _attempted = false,
      _restoring = true;
  bool _resetPending = false;
  final _scroll = ScrollController();
  int _generation = 0;
  String? _lastRead;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _thread = widget.initial;
    ChatNavigation.activeThread = widget.threadId;
    _restore();
    _load(reset: true);
    _channel = _service.watchRoom(
      widget.threadId,
      (reset) {
        _resetPending = _resetPending || reset;
        _events?.cancel();
        _events = Timer(const Duration(milliseconds: 250), () {
          final clear = _resetPending;
          _resetPending = false;
          _load(reset: clear);
        });
      },
      (value) {
        if (mounted) setState(() => _connected = value);
      },
    );
    _clock = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_visible) _load();
    });
    _auth = _service.client.auth.onAuthStateChange.listen((_) {
      if (mounted && _service.userId != _account) Navigator.pop(context);
    });
  }

  bool get _visible =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  ChatDraft get _draft =>
      ChatDraft(id: _id, text: _text.text, photo: _photo, replyId: _reply);
  Future<void> _restore() async {
    try {
      final draft = await _store.load(_account!, widget.threadId);
      final wall = await _store.wallpaper(_account, widget.threadId);
      if (!mounted) return;
      setState(() {
        if (draft != null) {
          _id = draft.id;
          _text.text = draft.text;
          _photo = draft.photo;
          _reply = draft.replyId;
          _attempted = true;
        }
        if (wall['photo'] is String)
          _wallpaper = base64Decode(wall['photo'] as String);
      });
    } catch (_) {
      _notice('Não foi possível restaurar o rascunho neste aparelho.');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(text),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          ),
        );
    }
  }

  void _edited() {
    if (_attempted) {
      _id = CommunityService.newPostId();
      _attempted = false;
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      if (_account != null)
        unawaited(
          _store.save(_account, widget.threadId, _draft).catchError((Object _) {
            _notice('Não foi possível salvar o rascunho neste aparelho.');
          }),
        );
    });
    setState(() {});
  }

  Future<void> _load({bool older = false, bool reset = false}) async {
    if (older && (_loading || !_more)) return;
    final generation = ++_generation;
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await _service.messages(
        widget.threadId,
        before: older && _messages.isNotEmpty ? _messages.last : null,
      );
      final info = await _service.inbox(thread: widget.threadId);
      if (!mounted || generation != _generation || _service.userId != _account)
        return;
      setState(() {
        if (reset || info.isEmpty) _messages.clear();
        final merged = {
          for (final m in _messages) m.id: m,
          for (final m in rows) m.id: m,
        };
        _messages
          ..clear()
          ..addAll(
            merged.values.where((m) => m.expiresAt.isAfter(DateTime.now())),
          )
          ..sort((a, b) {
            final time = b.createdAt.compareTo(a.createdAt);
            return time == 0 ? b.id.compareTo(a.id) : time;
          });
        if (older || reset) _more = rows.length == 40;
        _thread = info.isEmpty ? null : info.first;
        _failed = false;
      });
      if (_visible &&
          (!_scroll.hasClients || _scroll.offset < 80) &&
          _messages.isNotEmpty) {
        final incoming = _messages
            .where((m) => m.senderId != _account)
            .firstOrNull;
        if (incoming != null && incoming.id != _lastRead) {
          await _service.markRead(widget.threadId, incoming.id);
          _lastRead = incoming.id;
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _restoring || (_text.text.trim().isEmpty && _photo == null))
      return;
    _draftTimer?.cancel();
    final draft = _draft;
    setState(() => _sending = true);
    _attempted = true;
    _sendEntrances.add(draft.id);
    try {
      await _store.save(_account!, widget.threadId, draft);
      await _service.send(widget.threadId, draft);
      if (!mounted) return;
      setState(() {
        _text.clear();
        _photo = null;
        _reply = null;
        _id = CommunityService.newPostId();
        _attempted = false;
      });
      try {
        await _store.save(_account, widget.threadId, _draft);
      } catch (_) {
        _notice('Mensagem enviada. Não foi possível limpar o rascunho local.');
      }
      await _load();
    } catch (_) {
      _notice(
        'Não foi possível confirmar o envio. Sua mensagem foi mantida; tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pick({bool wallpaper = false}) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 15 * 1024 * 1024) throw ArgumentError();
      final bytes = await prepareChatImage(await file.readAsBytes());
      if (!mounted) return;
      if (wallpaper) {
        await _store.saveWallpaper(_account!, widget.threadId, 'custom', bytes);
        if (mounted) setState(() => _wallpaper = bytes);
      } else {
        setState(() => _photo = bytes);
        _edited();
      }
    } catch (_) {
      _notice('Escolha uma foto estática de até 15 MB.');
    }
  }

  Future<void> _actions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Responder'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            if (message.body.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copiar texto'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            if (message.senderId == _account)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Excluir mensagem'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || _sending) return;
    if (action == 'reply') {
      setState(() => _reply = message.id);
      _edited();
    }
    if (action == 'copy')
      await Clipboard.setData(ClipboardData(text: message.body));
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Excluir mensagem?'),
          content: const Text('Ela será removida para os dois participantes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        try {
          await _service.delete(message.id);
          await _load(reset: true);
        } catch (_) {
          _notice('Não foi possível excluir. Tente novamente.');
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ChatNavigation.activeThread = state == AppLifecycleState.resumed
        ? widget.threadId
        : null;
    if (state == AppLifecycleState.resumed) _load(reset: true);
  }

  @override
  void dispose() {
    if (ChatNavigation.activeThread == widget.threadId)
      ChatNavigation.activeThread = null;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    _clock?.cancel();
    _draftTimer?.cancel();
    if (!_restoring && _account != null)
      unawaited(
        _store
            .save(_account, widget.threadId, _draft)
            .catchError((Object _) {}),
      );
    _text.dispose();
    _scroll.dispose();
    _auth?.cancel();
    if (_channel != null) unawaited(_service.close(_channel!));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _thread == null
              ? null
              : () async {
                  ChatNavigation.activeThread = null;
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PublicMemberProfileScreen(userId: _thread!.peerId),
                    ),
                  );
                  if (mounted) {
                    ChatNavigation.activeThread = widget.threadId;
                    _load(reset: true);
                  }
                },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: _thread?.avatar?.isNotEmpty == true
                    ? NetworkImage(_thread!.avatar!)
                    : _thread?.founder == true ? const AssetImage('assets/images/perfil.png') : null,
                onBackgroundImageError: _thread?.avatar?.isNotEmpty == true || _thread?.founder == true
                    ? (_, __) {}
                    : null,
                child: _thread?.avatar?.isNotEmpty == true || _thread?.founder == true
                    ? null
                    : const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _thread?.name ?? 'Conversa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Personalizar conversa',
            onSelected: (value) async {
              try {
                if (value == 'photo') {
                  await _pick(wallpaper: true);
                } else {
                  await _store.saveWallpaper(
                    _account!,
                    widget.threadId,
                    'default',
                    null,
                  );
                  if (mounted) setState(() => _wallpaper = null);
                }
              } catch (_) {
                _notice(
                  'Não foi possível alterar o papel de parede neste aparelho.',
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'photo',
                child: Text('Escolher papel de parede'),
              ),
              const PopupMenuItem(
                value: 'default',
                child: Text('Restaurar fundo'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Mensagens e anexos desaparecem após 7 dias.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ),
            if (_failed || !_connected)
              TextButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.sync),
                label: Text(
                  _failed
                      ? 'Não foi possível atualizar. Tentar novamente'
                      : 'Reconectando…',
                ),
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  image: _wallpaper == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(_wallpaper!),
                          fit: BoxFit.cover,
                          colorFilter: const ColorFilter.mode(
                            Colors.black54,
                            BlendMode.darken,
                          ),
                        ),
                ),
                child: _loading && _messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        reverse: true,
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.length + 1,
                        findChildIndexCallback: (key) {
                          if (key is! ValueKey<String>) return null;
                          final index = _messages.indexWhere(
                            (m) => m.id == key.value,
                          );
                          return index < 0 ? null : index;
                        },
                        itemBuilder: (_, index) {
                          if (index == _messages.length)
                            return _more && _messages.isNotEmpty
                                ? TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => _load(older: true),
                                    child: const Text(
                                      'Carregar mensagens anteriores',
                                    ),
                                  )
                                : _messages.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Comece a conversa com uma mensagem.',
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : const SizedBox.shrink();
                          final m = _messages[index],
                              mine = m.senderId == _account;
                          final reply = _messages
                              .where((r) => r.id == m.replyTo)
                              .firstOrNull;
                          return _SentMessageEntrance(
                            key: ValueKey(m.id),
                            animate: mine && _sendEntrances.contains(m.id),
                            onEnd: () => _sendEntrances.remove(m.id),
                            child: Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: GestureDetector(
                                onLongPress: _sending
                                    ? null
                                    : () => _actions(m),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * .8,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? Color.alphaBlend(
                                            colors.orange.withValues(alpha: .2),
                                            colors.surface,
                                          )
                                        : colors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: colors.borderSubtle,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (m.replyTo != null)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: colors.orange,
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            reply?.body.isNotEmpty == true
                                                ? reply!.body
                                                : reply?.imagePath != null
                                                ? 'Foto'
                                                : 'Mensagem indisponível',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      if (m.imagePath != null)
                                        m.imageUrl == null
                                            ? const Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Text(
                                                  'Foto indisponível. Atualize a conversa.',
                                                ),
                                              )
                                            : GestureDetector(
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                    builder: (_) => Scaffold(
                                                      backgroundColor:
                                                          Colors.black,
                                                      appBar: AppBar(),
                                                      body: Center(
                                                        child: InteractiveViewer(
                                                          child: Image.network(
                                                            m.imageUrl!,
                                                            fit: BoxFit.contain,
                                                            errorBuilder:
                                                                (
                                                                  _,
                                                                  __,
                                                                  ___,
                                                                ) => const Text(
                                                                  'Atualize a conversa para abrir a foto.',
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.network(
                                                    m.imageUrl!,
                                                    width: 240,
                                                    height: 240,
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 720,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => const SizedBox(
                                                          height: 100,
                                                          child: Center(
                                                            child: Icon(
                                                              Icons
                                                                  .broken_image_outlined,
                                                            ),
                                                          ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                      if (m.body.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: m.imagePath != null ? 8 : 0,
                                          ),
                                          child: Text(
                                            m.body,
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                          if (mine)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 5,
                                              ),
                                              child: Icon(
                                                Icons.done_all,
                                                size: 15,
                                                color:
                                                    _thread != null &&
                                                        !m.createdAt.isAfter(
                                                          _thread!.peerReadAt,
                                                        )
                                                    ? colors.orange
                                                    : colors.textSecondary,
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
                        },
                      ),
              ),
            ),
            if (_reply != null)
              ListTile(
                dense: true,
                leading: Icon(Icons.reply, color: colors.orange),
                title: const Text('Respondendo a uma mensagem'),
                trailing: IconButton(
                  tooltip: 'Cancelar resposta',
                  onPressed: _sending
                      ? null
                      : () {
                          setState(() => _reply = null);
                          _edited();
                        },
                  icon: const Icon(Icons.close),
                ),
              ),
            if (_photo != null)
              SizedBox(
                height: 90,
                child: Row(
                  children: [
                    Image.memory(_photo!, width: 90, fit: BoxFit.cover),
                    IconButton(
                      tooltip: 'Remover foto',
                      onPressed: _sending
                          ? null
                          : () {
                              setState(() => _photo = null);
                              _edited();
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Anexar foto',
                    onPressed: _sending || _restoring ? null : () => _pick(),
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: colors.orange,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: !_sending && !_restoring,
                      onChanged: (_) => _edited(),
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: 'Mensagem…',
                        counterText: '',
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Enviar mensagem',
                    onPressed: _sending || _restoring ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.send_rounded, color: colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentMessageEntrance extends StatelessWidget {
  const _SentMessageEntrance({
    super.key,
    required this.animate,
    required this.onEnd,
    required this.child,
  });
  final bool animate;
  final VoidCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate && !reduced ? 0 : 1, end: 1),
      duration: Duration(milliseconds: animate && !reduced ? 320 : 0),
      curve: Curves.easeOutCubic,
      onEnd: onEnd,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(10 * (1 - value), 14 * (1 - value)),
          child: Transform.scale(
            scale: .96 + .04 * value,
            alignment: Alignment.bottomRight,
            child: child,
          ),
        ),
      ),
    );
  }
}
