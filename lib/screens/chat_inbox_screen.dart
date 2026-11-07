import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';

const chatExpiryNotice = 'Mensagens e anexos desaparecem após 7 dias.';
Widget chatAvatar(String name, String? url, {double radius = 25, bool founder = false}) =>
    CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF25252A),
      foregroundImage: url == null || url.isEmpty
          ? founder ? const AssetImage('assets/images/perfil.png') : null
          : NetworkImage(url),
      onForegroundImageError: (url == null || url.isEmpty) && !founder ? null : (_, __) {},
      child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase()),
    );

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key, this.service});
  final ChatService? service;
  @override
  State<ChatInboxScreen> createState() => _ChatInboxState();
}

class _ChatInboxState extends State<ChatInboxScreen>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? ChatService();
  late final _account = _service.userId;
  final _search = TextEditingController();
  final _threads = <ChatThread>[];
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  Timer? _debounce, _events;
  bool _loading = true, _more = true, _failed = false, _connected = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _channel = _service.watchInbox(
      () {
        _events?.cancel();
        _events = Timer(const Duration(milliseconds: 250), () => _load());
      },
      (connected) {
        if (mounted) setState(() => _connected = connected);
      },
    );
    _auth = _service.client.auth.onAuthStateChange.listen((_) {
      if (_service.userId != _account && mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _debounce?.cancel();
    _events?.cancel();
    _search.dispose();
    _auth?.cancel();
    if (_channel != null) unawaited(_service.close(_channel!));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || !_more)) return;
    final generation = ++_generation;
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await _service.inbox(
        before: more && _threads.isNotEmpty ? _threads.last : null,
        query: _search.text.trim(),
      );
      if (!mounted || generation != _generation || _service.userId != _account)
        return;
      setState(() {
        if (!more) _threads.clear();
        final ids = _threads.map((t) => t.id).toSet();
        _threads.addAll(rows.where((t) => ids.add(t.id)));
        _more = rows.length == 30;
        _failed = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _open(ChatThread thread) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomScreen(
          threadId: thread.id,
          initial: thread,
          service: _service,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _new() async {
    final member = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pbhColors.surface,
      builder: (_) => _ChatMemberSearch(service: _service),
    );
    if (member == null || !mounted) return;
    try {
      final id = await _service.open(member['user_id'] as String);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ChatRoomScreen(threadId: id, service: _service),
        ),
      );
      if (mounted) _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível iniciar esta conversa. Verifique a conexão ou a disponibilidade do membro.',
            ),
          ),
        );
    }
  }

  String _time(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now))
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1))))
      return 'Ontem';
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Conversas'),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Nova conversa',
          onPressed: _new,
          icon: Icon(Icons.edit_square, color: context.pbhColors.orange),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _new,
      icon: const Icon(Icons.edit_square),
      label: const Text('Nova conversa'),
      backgroundColor: context.pbhColors.orange,
      foregroundColor: Colors.black,
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: TextField(
              controller: _search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _load(),
                );
              },
              decoration: InputDecoration(
                hintText: 'Buscar conversa',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.pbhColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Suas conversas são privadas',
              style: TextStyle(color: context.pbhColors.textSecondary),
            ),
          ),
          if (!_connected || _failed)
            TextButton.icon(
              onPressed: () => _load(),
              icon: const Icon(Icons.sync),
              label: Text(
                _failed
                    ? 'Não foi possível atualizar. Tentar novamente'
                    : 'Reconectando às conversas…',
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(),
              child: _loading && _threads.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _threads.length + 1,
                      separatorBuilder: (_, __) => Divider(
                        color: context.pbhColors.borderSubtle,
                        height: 1,
                        indent: 70,
                      ),
                      itemBuilder: (_, i) {
                        if (i == _threads.length)
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(8, 28, 8, 100),
                            child: Column(
                              children: [
                                if (_threads.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 30),
                                    child: Text(
                                      _failed
                                          ? 'Suas conversas aparecerão ao reconectar.'
                                          : _search.text.isNotEmpty
                                          ? 'Nenhuma conversa encontrada.'
                                          : 'Sua próxima conversa começa aqui.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                if (_more && _threads.isNotEmpty)
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => _load(more: true),
                                    child: Text(
                                      _loading
                                          ? 'Carregando…'
                                          : 'Carregar mais conversas',
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: context.pbhColors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.history,
                                        color: context.pbhColors.orange,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(chatExpiryNotice),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        final thread = _threads[i],
                            mine = thread.lastSender == _account;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 0,
                          ),
                          leading: chatAvatar(thread.name, thread.avatar, founder: thread.founder),
                          title: Text(
                            thread.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${mine ? 'Você: ' : ''}${thread.preview.isNotEmpty
                                  ? thread.preview
                                  : thread.hasImage
                                  ? 'Foto'
                                  : 'Inicie uma conversa'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _time(thread.lastAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (thread.unread > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Badge(
                                    backgroundColor: context.pbhColors.orange,
                                    textColor: Colors.black,
                                    label: Text(
                                      thread.unread > 99
                                          ? '99+'
                                          : '${thread.unread}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () => _open(thread),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChatMemberSearch extends StatefulWidget {
  const _ChatMemberSearch({required this.service});
  final ChatService service;
  @override
  State<_ChatMemberSearch> createState() => _ChatMemberSearchState();
}

class _ChatMemberSearchState extends State<_ChatMemberSearch> {
  final _query = TextEditingController();
  final _rows = <Map<String, dynamic>>[];
  Timer? _timer;
  int _version = 0, _offset = 0;
  bool _loading = false, _failed = false, _more = false;
  @override
  void dispose() {
    _version++;
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search({bool more = false}) async {
    final term = _query.text.trim();
    final version = ++_version;
    if (term.replaceFirst('@', '').length < 2) {
      setState(() => _rows.clear());
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await widget.service.search(
        term,
        offset: more ? _offset : 0,
      );
      if (!mounted || version != _version) return;
      setState(() {
        if (!more) {
          _rows.clear();
          _offset = 0;
        }
        _rows.addAll(rows);
        _offset += 30;
        _more = rows.length >= 29;
        _failed = false;
      });
    } catch (_) {
      if (mounted && version == _version) setState(() => _failed = true);
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .66,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nova conversa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Encontre pelo nome ou @usuário exclusivo.'),
            const SizedBox(height: 16),
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) {
                _timer?.cancel();
                _timer = Timer(
                  const Duration(milliseconds: 350),
                  () => _search(),
                );
              },
              decoration: const InputDecoration(
                hintText: 'Buscar membro',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _rows.isEmpty
                  ? Center(
                      child: Text(
                        _failed
                            ? 'Não foi possível buscar. Tente novamente.'
                            : 'Digite pelo menos 2 caracteres.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rows.length + (_more ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _rows.length)
                          return TextButton(
                            onPressed: _loading
                                ? null
                                : () => _search(more: true),
                            child: const Text('Carregar mais'),
                          );
                        final r = _rows[i];
                        final handle = r['handle'] as String?;
                        final automaticHandle =
                            'm_${(r['user_id'] as String).replaceAll('-', '')}';
                        return ListTile(
                          leading: chatAvatar(
                            r['name'] as String? ?? 'Membro',
                            r['avatar_url'] as String?,
                            founder: r['founder'] == true,
                          ),
                          title: Text(r['name'] as String? ?? 'Membro'),
                          subtitle:
                              handle == null ||
                                  handle.isEmpty ||
                                  handle == automaticHandle
                              ? null
                              : Text(
                                  '@$handle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => Navigator.pop(context, r),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
