import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/community_service.dart';

class CommunityHealthScreen extends StatefulWidget {
  const CommunityHealthScreen({super.key});
  @override
  State<CommunityHealthScreen> createState() => _CommunityHealthScreenState();
}

class _CommunityHealthScreenState extends State<CommunityHealthScreen> {
  final _client = Supabase.instance.client;
  Map<String, dynamic>? _health;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    final viewer = _client.auth.currentUser?.id;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await _client.rpc('admin_community_health') as Map;
      if (mounted && viewer == _client.auth.currentUser?.id)
        setState(() => _health = Map<String, dynamic>.from(row));
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Não foi possível consultar. Confira se as novas migrations foram aplicadas.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanup() async {
    if (_busy) return;
    setState(() => _busy = true);
    await CommunityService().cleanupPhotos(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _clear(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liberar participação?'),
        content: const Text('O membro poderá voltar a publicar e comentar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.rpc(
        'admin_clear_community_restriction',
        params: {'p_user': id},
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível liberar o membro.')),
        );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final health = _health;
    final lastRun = DateTime.tryParse(
      health?['last_run'] as String? ?? '',
    )?.toLocal();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico da comunidade'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          if (health != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Limpeza automática',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Agendamento: ${health['scheduled'] == true ? 'ativo' : 'inativo ou não encontrado'}',
                    ),
                    Text(
                      'Última execução: ${lastRun ?? 'ainda não registrada'}',
                    ),
                    Text(
                      'Resultado: ${health['last_status'] ?? 'sem registro'}',
                    ),
                    Text(
                      'Publicações vencidas aguardando limpeza: ${health['expired_posts']}',
                    ),
                    Text(
                      'Lotes de anexos pendentes: ${health['pending_media']}',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'As publicações dos membros expiram após 7 dias. As do líder são preservadas. Os anexos são removidos pela API de armazenamento, em lotes.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _cleanup,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Processar anexos pendentes'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Restrições ativas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if ((health['restrictions'] as List? ?? []).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhum membro com restrição ativa.'),
              ),
            for (final row in health['restrictions'] as List? ?? [])
              Card(
                child: ListTile(
                  title: Text(row['name'] as String),
                  subtitle: Text(
                    'Até ${DateTime.tryParse(row['until_at'] as String)?.toLocal()}',
                  ),
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () => _clear(row['user_id'] as String),
                    child: const Text('Liberar'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
