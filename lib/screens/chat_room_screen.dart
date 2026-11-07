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
import '../widgets/chat_voice_recorder.dart';
import '../widgets/chat_audio_player.dart';
import '../widgets/chat_reply_swipe.dart';
import '../widgets/chat_message_search.dart';

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
  final _replyContexts = <String, ChatMessage>{};
  final _composerFocus = FocusNode();
  bool _muted = false, _muteBusy = false, _peerTyping = false;
  RealtimeChannel? _typingChannel;
  Timer? _typingStop, _peerTypingExpiry;
  DateTime? _typingSent;
  Future<void> _stopTyping() async {
    _typingStop?.cancel();
    if (_typingSent == null) return;
    _typingSent = null;
    try {
      await _service.typing(widget.threadId, false);
    } catch (_) {}
  }

  void _typingEdited() {
    if (!_visible || _text.text.trim().isEmpty) {
      unawaited(_stopTyping());
      return;
    }
    _typingStop?.cancel();
    _typingStop = Timer(
      const Duration(seconds: 3),
      () => unawaited(_stopTyping()),
    );
    final now = DateTime.now();
    if (_typingSent == null ||
        now.difference(_typingSent!) >= const Duration(seconds: 3)) {
      _typingSent = now;
      unawaited(
        _service.typing(widget.threadId, true).catchError((Object _) {}),
      );
    }
  }

  Future<void> _readTyping() async {
    try {
      final until = await _service.peerTyping(widget.threadId);
      if (!mounted || _service.userId != _account) return;
      _peerTypingExpiry?.cancel();
      final remaining = until?.difference(DateTime.now()) ?? Duration.zero;
      setState(() => _peerTyping = remaining > Duration.zero);
      if (_peerTyping)
        _peerTypingExpiry = Timer(
          remaining > const Duration(seconds: 6)
              ? const Duration(seconds: 6)
              : remaining,
          () {
            if (mounted) setState(() => _peerTyping = false);
          },
        );
    } catch (_) {
      if (mounted) setState(() => _peerTyping = false);
    }
  }

  Future<void> _readMuted() async {
    try {
      final value = await _service.muted(widget.threadId);
      if (mounted && _service.userId == _account)
        setState(() => _muted = value);
    } catch (_) {}
  }

  Future<void> _toggleMuted() async {
    if (_muteBusy) return;
    setState(() => _muteBusy = true);
    try {
      await _service.setMuted(widget.threadId, !_muted);
      if (mounted) {
        setState(() => _muted = !_muted);
        _notice(
          _muted
              ? 'Conversa silenciada. As mensagens continuam chegando.'
              : 'Notificações desta conversa ativadas.',
        );
      }
    } catch (_) {
      _notice('Não foi possível alterar as notificações. Tente novamente.');
    } finally {
      if (mounted) setState(() => _muteBusy = false);
    }
  }

  void _respond(ChatMessage message) {
    if (_sending || !message.expiresAt.isAfter(DateTime.now())) return;
    setState(() {
      _reply = message.id;
      _replyContexts[message.id] = message;
    });
    _edited();
    _composerFocus.requestFocus();
  }

  Future<void> _searchConversation() async {
    unawaited(_stopTyping());
    final message = await showModalBottomSheet<ChatMessage>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ChatMessageSearch(service: _service, threadId: widget.threadId),
      ),
    );
    if (mounted && _service.userId == _account && message != null)
      _respond(message);
  }

  Uint8List? _photo, _wallpaper;
  ChatVoice? _voice;
  bool _recorderOpen = false;
  double _wallpaperDim = .54;
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
    _readMuted();
    _typingChannel = _service.watchTyping(widget.threadId, _readTyping);
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
      if (mounted && _service.userId != _account) {
        setState(() => _generation++);
        unawaited(ChatAudioPlayback.pauseAll());
        Navigator.pop(context);
      }
    });
  }

  bool get _visible =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  ChatDraft get _draft => ChatDraft(
    id: _id,
    text: _text.text,
    photo: _photo,
    replyId: _reply,
    voice: _voice,
  );
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
          _voice = draft.voice;
          _reply = draft.replyId;
          _attempted = true;
        }
        if (wall['photo'] is String)
          _wallpaper = base64Decode(wall['photo'] as String);
        _wallpaperDim = ((wall['dim'] as num?)?.toDouble() ?? .54).clamp(
          0,
          .85,
        );
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
    _typingEdited();
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
      final contexts = await _service.replyContext(
        widget.threadId,
        {
          ...rows.map((m) => m.replyTo).whereType<String>(),
          if (_reply != null) _reply!,
          ..._messages.map((m) => m.replyTo).whereType<String>(),
        }.toList(),
      );
      if (!mounted || generation != _generation || _service.userId != _account)
        return;
      setState(() {
        _replyContexts.clear();
        for (final m in contexts) {
          _replyContexts[m.id] = m;
        }
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
    if (_sending ||
        _restoring ||
        (_text.text.trim().isEmpty && _photo == null && _voice == null))
      return;
    _draftTimer?.cancel();
    unawaited(_stopTyping());
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
        _voice = null;
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

  Future<void> _record() async {
    if (_sending ||
        _restoring ||
        _recorderOpen ||
        _text.text.trim().isNotEmpty ||
        _photo != null ||
        _voice != null)
      return;
    setState(() => _recorderOpen = true);
    try {
      final voice = await showModalBottomSheet<ChatVoice>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: false,
        backgroundColor: context.pbhColors.surface,
        builder: (_) => const ChatVoiceRecorder(),
      );
      if (voice == null || !mounted || _service.userId != _account) return;
      setState(() => _voice = voice);
      _edited();
      await _send();
    } finally {
      if (mounted) setState(() => _recorderOpen = false);
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
        await _configureWallpaper(bytes);
      } else {
        setState(() => _photo = bytes);
        _edited();
      }
    } catch (_) {
      _notice('Escolha uma foto estática de até 15 MB.');
    }
  }

  Future<void> _configureWallpaper(Uint8List bytes) async {
    var dim = _wallpaperDim;
    final selected = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pbhColors.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Papel de parede',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ajuste o escurecimento para deixar a conversa mais confortável.',
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(bytes, fit: BoxFit.cover),
                          ColoredBox(
                            color: Colors.black.withValues(alpha: dim),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.pbhColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text('Prévia da conversa'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Escurecimento: ${(dim * 100).round()}%'),
                  Slider(
                    value: dim,
                    min: 0,
                    max: .85,
                    divisions: 17,
                    activeColor: context.pbhColors.orange,
                    label: '${(dim * 100).round()}%',
                    onChanged: (value) => update(() => dim = value),
                  ),
                  const Text(
                    'Essa personalização fica salva apenas neste aparelho.',
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, dim),
                    child: const Text('Salvar papel de parede'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted || _service.userId != _account) return;
    await _store.saveWallpaper(
      _account!,
      widget.threadId,
      'custom',
      bytes,
      dim: selected,
    );
    if (mounted)
      setState(() {
        _wallpaper = bytes;
        _wallpaperDim = selected;
      });
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
      _respond(message);
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
    if (state != AppLifecycleState.resumed)
      unawaited(_stopTyping());
    else {
      _readTyping();
      _readMuted();
    }
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
    unawaited(_stopTyping());
    _peerTypingExpiry?.cancel();
    _composerFocus.dispose();
    if (_typingChannel != null) unawaited(_service.close(_typingChannel!));
    if (!_restoring && _account != null && _service.userId == _account)
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
    if (_service.userId != _account) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversa')),
        body: const Center(
          child: Text('Sua conta mudou. Abra a conversa novamente.'),
        ),
      );
    }
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
                    : _thread?.founder == true
                    ? const AssetImage('assets/images/perfil.png')
                    : null,
                onBackgroundImageError:
                    _thread?.avatar?.isNotEmpty == true ||
                        _thread?.founder == true
                    ? (_, __) {}
                    : null,
                child:
                    _thread?.avatar?.isNotEmpty == true ||
                        _thread?.founder == true
                    ? null
                    : const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _thread?.name ?? 'Conversa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_peerTyping)
                      Text(
                        'digitando…',
                        style: TextStyle(fontSize: 12, color: colors.orange),
                      ),
                    if (_muted)
                      Text(
                        'Notificações silenciadas',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Personalizar conversa',
            onSelected: (value) async {
              if (value == 'search') {
                await _searchConversation();
                return;
              }
              if (value == 'mute') {
                await _toggleMuted();
                return;
              }
              try {
                if (value == 'photo') {
                  await _pick(wallpaper: true);
                } else if (value == 'dim' && _wallpaper != null) {
                  await _configureWallpaper(_wallpaper!);
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
                value: 'search',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.search_rounded),
                  title: Text('Buscar na conversa'),
                ),
              ),
              PopupMenuItem(
                value: 'mute',
                enabled: !_muteBusy,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _muted
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(
                    _muted ? 'Ativar notificações' : 'Silenciar conversa',
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'photo',
                child: Text('Escolher papel de parede'),
              ),
              if (_wallpaper != null)
                const PopupMenuItem(
                  value: 'dim',
                  child: Text('Escurecer papel de parede'),
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
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: _wallpaperDim),
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
                          final reply =
                              _messages
                                  .where((r) => r.id == m.replyTo)
                                  .firstOrNull ??
                              _replyContexts[m.replyTo];
                          return _SentMessageEntrance(
                            key: ValueKey(m.id),
                            animate: mine && _sendEntrances.contains(m.id),
                            onEnd: () => _sendEntrances.remove(m.id),
                            child: Align(
                              alignment: mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ChatReplySwipe(
                                onReply: _sending ? null : () => _respond(m),
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
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
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
                                                    : reply?.audioPath != null
                                                    ? 'Áudio'
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
                                                                fit: BoxFit
                                                                    .contain,
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
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
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
                                          if (m.audioPath != null)
                                            ChatAudioPlayer(
                                              format: m.audioFormat ?? 'm4a',
                                              key: ValueKey('audio-${m.id}'),
                                              load: () => _service.audio(
                                                widget.threadId,
                                                m,
                                              ),
                                              durationMs:
                                                  m.audioDurationMs ?? 1,
                                            ),
                                          if (m.body.isNotEmpty)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: m.imagePath != null
                                                    ? 8
                                                    : 0,
                                              ),
                                              child: Text(
                                                m.body,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                        ],
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
                subtitle: Text(
                  (_messages.where((m) => m.id == _reply).firstOrNull ??
                                  _replyContexts[_reply])
                              ?.body
                              .isNotEmpty ==
                          true
                      ? (_messages.where((m) => m.id == _reply).firstOrNull ??
                                _replyContexts[_reply])!
                            .body
                      : (_replyContexts[_reply]?.audioPath != null
                            ? 'Mensagem de áudio'
                            : 'Foto ou mensagem'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
                    tooltip: _voice != null ? 'Descartar áudio' : 'Anexar foto',
                    onPressed: _sending || _restoring || _recorderOpen
                        ? null
                        : _voice != null
                        ? () {
                            setState(() => _voice = null);
                            _edited();
                          }
                        : () => _pick(),
                    icon: Icon(
                      _voice != null
                          ? Icons.delete_outline
                          : Icons.add_photo_alternate_outlined,
                      color: colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _voice != null
                        ? ChatAudioPlayer(
                            format: _voice!.format,
                            key: ValueKey('draft-$_id'),
                            load: () async => _voice!.bytes,
                            durationMs: _voice!.durationMs,
                          )
                        : TextField(
                            controller: _text,
                            focusNode: _composerFocus,
                            enabled: !_sending && !_restoring && !_recorderOpen,
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
                    tooltip: _voice != null
                        ? 'Enviar áudio'
                        : _text.text.trim().isNotEmpty || _photo != null
                        ? 'Enviar mensagem'
                        : 'Gravar áudio',
                    onPressed: _sending || _restoring || _recorderOpen
                        ? null
                        : _voice != null ||
                              _text.text.trim().isNotEmpty ||
                              _photo != null
                        ? _send
                        : _record,
                    icon: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AnimatedSwitcher(
                            duration: Duration(
                              milliseconds:
                                  MediaQuery.disableAnimationsOf(context)
                                  ? 0
                                  : 160,
                            ),
                            child: Icon(
                              _voice != null ||
                                      _text.text.trim().isNotEmpty ||
                                      _photo != null
                                  ? Icons.send_rounded
                                  : Icons.mic_rounded,
                              key: ValueKey(
                                _voice != null ||
                                    _text.text.trim().isNotEmpty ||
                                    _photo != null,
                              ),
                              color: colors.orange,
                            ),
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
