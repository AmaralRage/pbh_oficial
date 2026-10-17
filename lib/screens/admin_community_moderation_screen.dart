import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class AdminCommunityModerationScreen extends StatefulWidget {
  const AdminCommunityModerationScreen({super.key});

  @override
  State<AdminCommunityModerationScreen> createState() => _AdminCommunityModerationScreenState();
}

class _AdminCommunityModerationScreenState extends State<AdminCommunityModerationScreen> {
  List<Map<String, dynamic>> _reports = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client
          .from('community_admin_report_feed')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() { _reports = rows.map((row) => Map<String, dynamic>.from(row)).toList(); _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _review(Map<String, dynamic> report, String action) async {
    final remove = action == 'remove';
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remover publicação?'),
          content: const Text('A publicação denunciada será removida da comunidade.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await Supabase.instance.client.rpc('review_community_report', params: {'p_report_id': report['id'], 'p_action': action});
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível revisar a denúncia: $error')));
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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Moderação da comunidade')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Não foi possível carregar as denúncias. Confira a migration 20261017000300.\n\n$_error', textAlign: TextAlign.center)))
                : _reports.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Nenhuma denúncia aguardando revisão.', style: AppTextStyles.bodySmall)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(18),
                          itemCount: _reports.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final report = _reports[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderSubtle)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [const Icon(Icons.flag_outlined, color: AppColors.orange), const SizedBox(width: 8), Text(_reasonLabel(report['reason'] as String? ?? 'other'), style: AppTextStyles.titleMedium)]),
                                const SizedBox(height: 8),
                                Text('Publicação de ${report['post_author'] ?? 'Membro'}', style: AppTextStyles.statLabel),
                                const SizedBox(height: 8),
                                Text(report['post_content'] as String? ?? '', style: AppTextStyles.body),
                                const SizedBox(height: 14),
                                Wrap(spacing: 10, runSpacing: 8, children: [
                                  OutlinedButton(onPressed: () => _review(report, 'keep'), child: const Text('Manter publicação')),
                                  ElevatedButton.icon(onPressed: () => _review(report, 'remove'), icon: const Icon(Icons.delete_outline), label: const Text('Remover')),
                                ]),
                              ]),
                            );
                          },
                        ),
                      ),
      );
}
