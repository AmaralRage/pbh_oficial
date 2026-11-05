import 'profile_surface.dart';
import '../core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberHandle extends StatefulWidget {
  const MemberHandle({
    super.key,
    required this.userId,
    required this.child,
    this.client,
  });
  final String userId;
  final Widget child;
  final SupabaseClient? client;
  @override
  State<MemberHandle> createState() => _MemberHandleState();
}

class _MemberHandleState extends State<MemberHandle> {
  late final _client = widget.client ?? Supabase.instance.client;
  String? _handle;
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MemberHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _handle = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.userId, viewer = _client.auth.currentUser?.id;
    try {
      final value = await _client.rpc('member_handle', params: {'p_user': id});
      if (mounted &&
          id == widget.userId &&
          viewer == _client.auth.currentUser?.id)
        setState(() => _handle = value as String?);
    } catch (_) {
      /* Older servers can still display the profile. */
    }
  }

  Future<void> _edit() async {
    final viewer = _client.auth.currentUser?.id;
    if (viewer != widget.userId) return;
    final input = _input..text = _handle ?? '';
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Seu nome de usuário'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Um identificador único para encontrar você, mesmo quando outras pessoas têm o mesmo nome.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: input,
                maxLength: 40,
                enabled: !saving,
                autocorrect: false,
                decoration: InputDecoration(
                  prefixText: '@',
                  labelText: 'Nome de usuário',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      refresh(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        if (viewer != _client.auth.currentUser?.id)
                          throw StateError('A conta mudou.');
                        final value = await _client.rpc(
                          'set_member_handle',
                          params: {'p_handle': input.text.trim()},
                        );
                        if (mounted && viewer == _client.auth.currentUser?.id)
                          setState(() => _handle = value as String);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted)
                          refresh(() {
                            saving = false;
                            error = e is PostgrestException
                                ? e.message
                                : 'Não foi possível salvar. Tente novamente.';
                          });
                      }
                    },
              child: Text(saving ? 'Salvando…' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final own = _client.auth.currentUser?.id == widget.userId;
    if (_handle == null && !own) return widget.child;
    final label = _handle == null ? 'Escolher @usu\u00e1rio' : '@$_handle';
    if (own &&
        (_handle == null ||
            _handle == 'm_${widget.userId.replaceAll('-', '')}')) {
      final automatic = _handle == 'm_${widget.userId.replaceAll('-', '')}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.child,
          InkWell(
            onTap: _edit,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (automatic)
            Text(
              'Este é seu nome automático. Toque para personalizar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      );
    }
    return Tooltip(
      message: label,
      child: PopupMenuButton<String>(
        tooltip: '',
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        menuPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
        position: PopupMenuPosition.under,
        onSelected: (action) async {
          if (action == 'edit') {
            await _edit();
            return;
          }
          if (_handle == null) return;
          await Clipboard.setData(ClipboardData(text: '@$_handle'));
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nome de usu\u00e1rio copiado.')),
            );
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: ProfileSurfaceScope(
              enabled: ProfileSurfaceScope.enabledOf(context),
              child: Builder(
                builder: (menuContext) => ProfileSurface(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.pbhColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.pbhColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: context.pbhColors.orange.withValues(
                                alpha: .12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.alternate_email_rounded,
                              size: 21,
                              color: context.pbhColors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nome de usu\u00e1rio',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.pbhColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: context.pbhColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(
                          height: 1,
                          color: context.pbhColors.borderSubtle,
                        ),
                      ),
                      if (_handle != null)
                        _HandleMenuAction(
                          icon: Icons.copy_outlined,
                          label: 'Copiar @usu\u00e1rio',
                          onTap: () => Navigator.pop(menuContext, 'copy'),
                        ),
                      if (own)
                        _HandleMenuAction(
                          icon: Icons.edit_outlined,
                          label: 'Editar @usu\u00e1rio',
                          onTap: () => Navigator.pop(menuContext, 'edit'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        child: widget.child,
      ),
    );
  }
}

class _HandleMenuAction extends StatelessWidget {
  const _HandleMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.pbhColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.pbhColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
