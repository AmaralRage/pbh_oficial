import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/community_service.dart';
import '../widgets/community_post_card.dart';
import 'community_health_screen.dart';

class AdminCommunityModerationScreen extends StatefulWidget {
  const AdminCommunityModerationScreen({super.key});

  @override
  State<AdminCommunityModerationScreen> createState() =>
      _AdminCommunityModerationScreenState();
}

class _AdminCommunityModerationScreenState
    extends State<AdminCommunityModerationScreen> {
  List<Map<String, dynamic>> _reports = const [];
  bool _loading = true;
  String? _error;
  bool _reviewing = false;
  bool _more = false;
  int _limit = 50;

  Future<void> _openPost(String id) async {
    try {
      final service = CommunityService();
      final post = await service.postById(id);
      if (!mounted) return;
      if (post == null) throw StateError('Publicação indisponível.');
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Publicação denunciada')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CommunityPostCard(
                post: post,
                isAuthenticated: true,
                onRequireLogin: () {},
                onChanged: () async {},
              ),
            ),
          ),
        ),
      );
      if (mounted) _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicação indisponível ou removida.')),
        );
    }
  }

  Future<void> _restrict(Map<String, dynamic> report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restringir participação por 7 dias?'),
        content: const Text(
          'O membro poderá ler a comunidade, mas não publicar nem comentar durante esse período. A restrição pode ser retirada no diagnóstico da comunidade.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restringir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _reviewing) return;
    setState(() => _reviewing = true);
    try {
      await Supabase.instance.client.rpc(
        'admin_restrict_community_member',
        params: {'p_post': report['post_id'], 'p_days': 7},
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Participação restrita por 7 dias.')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível restringir este membro.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('community_admin_report_feed')
          .select()
          .order('created_at', ascending: false)
          .order('id')
          .limit(_limit);
      if (!mounted) return;
      setState(() {
        _reports = rows.map((row) => Map<String, dynamic>.from(row)).toList();
        _more = rows.length == _limit;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  Future<void> _review(Map<String, dynamic> report, String action) async {
    final remove = action == 'remove';
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remover publicação?'),
          content: const Text(
            'A publicação denunciada será removida da comunidade.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await Supabase.instance.client.rpc(
        'review_community_report',
        params: {'p_report_id': report['id'], 'p_action': action},
      );
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível revisar a denúncia: $error'),
          ),
        );
    }
  }

  String _reasonLabel(String value) => switch (value) {
    'spam' => 'Spam',
    'harassment' => 'Assédio',
    'inappropriate' => 'Conteúdo inadequado',
    _ => 'Outro motivo',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.pbhColors.background,
    appBar: AppBar(
      title: const Text('Moderação da comunidade'),
      actions: [
        IconButton(
          tooltip: 'Diagnóstico da comunidade',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CommunityHealthScreen(),
            ),
          ),
          icon: const Icon(Icons.monitor_heart_outlined),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível carregar as denúncias. Confira a migration 20261017000300.\n\n$_error',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : _reports.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nenhuma denúncia aguardando revisão.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: _reports.length + (_more ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _reports.length)
                  return TextButton(
                    onPressed: () {
                      _limit += 50;
                      _load();
                    },
                    child: const Text('Carregar mais denúncias'),
                  );
                final report = _reports[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.pbhColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.pbhColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            color: context.pbhColors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _reasonLabel(
                              report['reason'] as String? ?? 'other',
                            ),
                            style: AppTextStyles.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Publicação de ${report['post_author'] ?? 'Membro'}',
                        style: AppTextStyles.statLabel,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report['post_content'] as String? ?? '',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _openPost(report['post_id'] as String),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Abrir publicação'),
                          ),
                          TextButton.icon(
                            onPressed: _reviewing
                                ? null
                                : () => _restrict(report),
                            icon: const Icon(Icons.person_off_outlined),
                            label: const Text('Restringir por 7 dias'),
                          ),
                          OutlinedButton(
                            onPressed: () => _review(report, 'keep'),
                            child: const Text('Manter publicação'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _review(report, 'remove'),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remover'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
  );
}
