import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/private_support_service.dart';
import '../screens/support_history_screen.dart';

class SupportReplyNotice extends StatefulWidget {
  const SupportReplyNotice({
    super.key,
    required this.onChanged,
    required this.onCountChanged,
    this.service,
  });
  final VoidCallback onChanged;
  final ValueChanged<int> onCountChanged;
  final PrivateSupportService? service;
  @override
  State<SupportReplyNotice> createState() => _SupportReplyNoticeState();
}

class _SupportReplyNoticeState extends State<SupportReplyNotice> {
  late final _service = widget.service ?? PrivateSupportService();
  late final _account = _service.currentUserId;
  StreamSubscription? _auth;
  int _count = 0;
  bool _failed = false, _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
    _auth = _service.authChanges.listen((_) {
      if (mounted && _account != _service.currentUserId) {
        setState(() => _count = 0);
        widget.onCountChanged(0);
      }
    });
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final count = await _service.unreadCount();
      if (!mounted || _account != _service.currentUserId) return;
      setState(() {
        _count = count;
        _failed = false;
      });
      widget.onCountChanged(count);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final request = await _service.latestUnreadRequest();
      if (!mounted || _account != _service.currentUserId) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => request == null
              ? const SupportHistoryScreen()
              : SupportRequestScreen(request: request),
        ),
      );
      await _load();
      widget.onChanged();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o atendimento. Confira a conexão e tente novamente.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed)
      return TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text(
          'Não foi possível consultar o suporte. Tentar novamente',
        ),
      );
    if (_count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: Icon(
            Icons.support_agent_rounded,
            color: context.pbhColors.orange,
          ),
          title: const Text('A equipe respondeu ao seu pedido'),
          subtitle: Text(
            '$_count ${_count == 1 ? 'resposta não lida' : 'respostas não lidas'} · Abrir atendimento',
          ),
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _busy ? null : _open,
        ),
      ),
    );
  }
}
