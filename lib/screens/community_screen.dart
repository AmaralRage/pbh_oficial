import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';
import '../widgets/community_post_card.dart';
import '../widgets/filter_chip_row.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.isAuthenticated, required this.onRequireLogin});

  final bool isAuthenticated;
  final VoidCallback onRequireLogin;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _service = CommunityService();
  int _filterIndex = 0;
  static const _filters = ['Para você', 'Seguindo', 'Conquistas', 'Populares'];
  List<CommunityPostModel> _posts = const [];
  CommunityStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final posts = await _service.fetchPosts(filterIndex: _filterIndex);
      CommunityStats? stats;
      // Estatísticas são complementares. Uma falha na RPC não deve esconder o feed.
      try {
        stats = await _service.fetchStats();
      } catch (_) {
        stats = null;
      }
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _stats = stats;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = _friendlyError(error); });
    }
  }

  String _friendlyError(Object error) {
    final details = error.toString();
    final normalized = details.toLowerCase();
    if (normalized.contains('community_feed') &&
        (normalized.contains('pgrst205') || normalized.contains('schema cache') || normalized.contains('does not exist'))) {
      return 'A estrutura da comunidade ainda não existe no Supabase. Execute a migration supabase/migrations/20261015000300_community_progress.sql no SQL Editor.';
    }
    if (normalized.contains('permission denied') || normalized.contains('42501')) {
      return 'O Supabase recusou a consulta por falta de permissão. Confira as políticas RLS da migration 20261015000300.';
    }
    return details;
  }

  Future<void> _selectFilter(int index) async {
    if (_filterIndex == index) return;
    setState(() { _filterIndex = index; _loading = true; });
    await _load(showLoading: false);
  }

  Future<void> _composePost() async {
    if (!widget.isAuthenticated) {
      widget.onRequireLogin();
      return;
    }
    final contentController = TextEditingController();
    final tagController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final publish = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SafeArea(top: false, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Nova publicação', style: AppTextStyles.titleLarge),
          const SizedBox(height: 14),
          TextFormField(controller: contentController, minLines: 4, maxLines: 8, maxLength: 2000, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Compartilhe sua jornada com a comunidade...', alignLabelWithHint: true), validator: (value) => value == null || value.trim().isEmpty ? 'Escreva sua publicação.' : null),
          TextField(controller: tagController, maxLength: 80, decoration: const InputDecoration(labelText: 'Conquista (opcional)', prefixIcon: Icon(Icons.emoji_events_outlined))),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(sheetContext, true); }, icon: const Icon(Icons.send_rounded), label: const Text('Publicar')),
        ]))),
      )),
    );
    if (publish != true || !mounted) {
      contentController.dispose();
      tagController.dispose();
      return;
    }
    try {
      await _service.createPost(contentController.text, achievementTag: tagController.text);
      if (!mounted) return;
      contentController.dispose();
      tagController.dispose();
      setState(() => _filterIndex = 0);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicação compartilhada.')));
    } catch (error) {
      contentController.dispose();
      tagController.dispose();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível publicar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _load(showLoading: false),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Comunidade', style: AppTextStyles.headline),
              IconButton(tooltip: 'Criar publicação', icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary), onPressed: _composePost),
            ]),
            const SizedBox(height: 6),
            Text('Homens comprometidos com a mesma jornada.', style: AppTextStyles.bodySmall),
            const SizedBox(height: 20),
            if (_stats != null) _StatsPanel(stats: _stats!),
            const SizedBox(height: 20),
            FilterChipRow(options: _filters, selectedIndex: _filterIndex, onSelected: _selectFilter),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _FeedMessage(icon: Icons.cloud_off_outlined, message: 'Não foi possível carregar a comunidade.', details: _error, action: 'Tentar novamente', onTap: _load)
            else if (_posts.isEmpty)
              _FeedMessage(icon: Icons.forum_outlined, message: _filterIndex == 1 ? 'Você ainda não segue ninguém.' : 'Ainda não há publicações por aqui.', action: _filterIndex == 1 ? null : 'Criar publicação', onTap: _filterIndex == 1 ? null : _composePost)
            else
              ..._posts.map((post) => Padding(
                    key: ValueKey(post.id),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: CommunityPostCard(post: post, isAuthenticated: widget.isAuthenticated, onRequireLogin: widget.onRequireLogin, onChanged: () => _load(showLoading: false)),
                  )),
          ],
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});
  final CommunityStats stats;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderSubtle)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _Stat(value: '${stats.posts}', label: 'Publicações'),
          Container(width: 1, height: 30, color: AppColors.borderSubtle),
          _Stat(value: '${stats.comments}', label: 'Comentários'),
          Container(width: 1, height: 30, color: AppColors.borderSubtle),
          _Stat(value: '${stats.likes}', label: 'Curtidas'),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: AppTextStyles.statNumber), const SizedBox(height: 4), Text(label, style: AppTextStyles.statLabel)]);
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({required this.icon, required this.message, this.details, this.action, this.onTap});
  final IconData icon;
  final String message;
  final String? details;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 45), child: Column(children: [Icon(icon, size: 34, color: AppColors.textTertiary), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodySmall), if (details != null) ...[const SizedBox(height: 8), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Text(details!, textAlign: TextAlign.center, style: AppTextStyles.statLabel))], if (action != null) TextButton(onPressed: onTap, child: Text(action!))]));
}
