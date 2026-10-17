import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class BlockedMembersScreen extends StatefulWidget {
  const BlockedMembersScreen({super.key});

  @override
  State<BlockedMembersScreen> createState() => _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends State<BlockedMembersScreen> {
  Map<String, String> _members = const {};
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
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw StateError('Entre na sua conta para gerenciar membros bloqueados.');
      final blocks = await client.from('community_blocks').select('blocked_id').eq('blocker_id', userId);
      final ids = blocks.map((row) => row['blocked_id'] as String).toList();
      if (ids.isEmpty) {
        if (mounted) setState(() { _members = const {}; _loading = false; });
        return;
      }
      final posts = await client.from('community_feed').select('user_id,author_name').inFilter('user_id', ids);
      final names = <String, String>{for (final row in posts) row['user_id'] as String: row['author_name'] as String? ?? 'Membro'};
      if (mounted) setState(() { _members = {for (final id in ids) id: names[id] ?? 'Membro'}; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _unblock(String id) async {
    try {
      await Supabase.instance.client.from('community_blocks').delete().eq('blocker_id', Supabase.instance.client.auth.currentUser!.id).eq('blocked_id', id);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível desbloquear: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Membros bloqueados')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Não foi possível carregar a lista. Confira a migration da comunidade.\n\n$_error', textAlign: TextAlign.center)))
                : _members.isEmpty
                    ? Center(child: Text('Você ainda não bloqueou ninguém.', style: AppTextStyles.bodySmall))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(padding: const EdgeInsets.all(16), children: [
                          for (final entry in _members.entries)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
                              child: ListTile(
                                leading: const CircleAvatar(backgroundColor: AppColors.orangeDim, child: Icon(Icons.person_outline, color: AppColors.orange)),
                                title: Text(entry.value, style: AppTextStyles.titleMedium),
                                subtitle: Text(entry.key, style: AppTextStyles.statLabel),
                                trailing: TextButton(onPressed: () => _unblock(entry.key), child: const Text('Desbloquear')),
                              ),
                            ),
                        ]),
                      ),
      );
}
