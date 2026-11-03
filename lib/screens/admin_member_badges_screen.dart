import '../widgets/admin_member_picker.dart';
import '../services/auth_service.dart';
import '../widgets/member_badge_icon.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';

class AdminMemberBadgesScreen extends StatefulWidget {
  const AdminMemberBadgesScreen({super.key});
  @override
  State<AdminMemberBadgesScreen> createState() =>
      _AdminMemberBadgesScreenState();
}

class _AdminMemberBadgesScreenState extends State<AdminMemberBadgesScreen> {
  Map<String, dynamic>? _recipient;
  bool get _leader => AuthService.isProjectLeader(_client.auth.currentUser);
  final _form = GlobalKey<FormState>();
  final _client = Supabase.instance.client;
  String _badge = 'guardian';
  bool _loading = true, _allowed = false, _busy = false;
  String? _error;
  static const labels = {
    'guardian': 'Guardi\u00e3o',
    'mentor': 'Mentor',
    'ambassador': 'Embaixador',
    'beginner': 'Iniciante',
    'consistent': 'Constante',
    'veteran': 'Veterano',
  };
  final _search = TextEditingController();
  List<Map<String, dynamic>> _awards = [];
  bool _awardsLoading = false, _more = true;
  String? _awardsError;
  Future<void> _loadAwards({bool reset = false}) async {
    if (_awardsLoading || !_allowed) return;
    setState(() {
      _awardsLoading = true;
      _awardsError = null;
    });
    try {
      final rows =
          await _client.rpc(
                'admin_list_member_badges',
                params: {
                  'p_offset': reset ? 0 : _awards.length,
                  'p_query': _search.text.trim(),
                },
              )
              as List;
      if (mounted)
        setState(() {
          if (reset) _awards = [];
          _awards.addAll(rows.map((r) => Map<String, dynamic>.from(r as Map)));
          _more = rows.length == 30;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _awardsError = 'Não foi possível carregar os selos concedidos.',
        );
    } finally {
      if (mounted) setState(() => _awardsLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final allowed = await _client.rpc('is_admin');
      if (mounted) setState(() => _allowed = allowed == true || _leader);
      if (_allowed && mounted) await _loadAwards(reset: true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'N\u00e3o foi poss\u00edvel verificar seu acesso.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();

    super.dispose();
  }

  Future<void> _save(bool grant) async {
    if (_busy || !_allowed) return;
    if (_recipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha um membro primeiro.')),
      );
      return;
    }
    final recipient = Map<String, dynamic>.from(_recipient!), badge = _badge;
    final name = recipient['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(grant ? 'Conceder selo?' : 'Remover selo?'),
        content: Text(
          '${labels[badge]} para $name.\n\nO selo aparece junto ao nome na comunidade e no perfil p\u00fablico. Se houver mais de um selo, a prioridade \u00e9 Guardi\u00e3o, Mentor, Embaixador, Veterano, Constante e Iniciante. Remover uma concess\u00e3o manual n\u00e3o remove um selo j\u00e1 conquistado automaticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _client.rpc(
        'admin_set_user_member_badge',
        params: {
          'p_user': recipient['user_id'],
          'p_badge': badge,
          'p_grant': grant,
        },
      );
      if (mounted) await _loadAwards(reset: true);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(grant ? 'Selo concedido.' : 'Selo removido.')),
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'N\u00e3o foi poss\u00edvel alterar o selo. Confira o membro selecionado, sua permiss\u00e3o e a migra\u00e7\u00e3o no Supabase.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _badgeOption(String id, String label) {
    final colors = context.pbhColors;
    final selected = _badge == id;
    final color = switch (id) {
      'guardian' => const Color(0xFFD0ADFF),
      'mentor' => const Color(0xFFA5C2FF),
      'beginner' => const Color(0xFFE0A779),
      'consistent' => const Color(0xFF69E8CB),
      'veteran' => const Color(0xFFA5C2FF),
      _ => const Color(0xFF69E8CB),
    };
    final description = switch (id) {
      'guardian' => 'Reconhece quem protege o respeito e cuida da comunidade.',
      'beginner' =>
        'Automático após 5 tarefas de rotina concluídas. O líder pode antecipar.',
      'consistent' =>
        'Automático após 90 dias distintos com tarefas registradas. O líder pode antecipar.',
      'veteran' =>
        'Automático após 1 ano da criação da conta. O líder pode antecipar.',
      'mentor' =>
        'Valoriza quem orienta e apoia o desenvolvimento dos membros.',
      _ => 'Reconhece quem representa o PBH e compartilha seus valores.',
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? Color.alphaBlend(color.withValues(alpha: .1), colors.surface)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? color : colors.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap:
              _busy ||
                  (!_leader &&
                      const ['beginner', 'consistent', 'veteran'].contains(id))
              ? null
              : () => setState(() => _badge = id),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 7),
                          MemberBadgeIcon(badge: id, color: color, size: 18),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: selected ? color : colors.textTertiary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Selos de membros')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : !_allowed
        ? Center(child: Text(_error ?? 'Acesso reservado aos administradores.'))
        : Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: context.pbhColors.orange,
                  size: 40,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reconhe\u00e7a quem cuida da comunidade',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Guardi\u00e3o: cuidado com a comunidade.\nMentor: apoio e orienta\u00e7\u00e3o aos membros.\nEmbaixador: representa\u00e7\u00e3o e divulga\u00e7\u00e3o do projeto.\n\nEsses selos s\u00e3o reconhecimentos visuais e n\u00e3o concedem permiss\u00f5es administrativas. O selo de l\u00edder continua exclusivo do fundador.',
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final member =
                              await showModalBottomSheet<Map<String, dynamic>>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => const AdminMemberPicker(),
                              );
                          if (member != null && mounted)
                            setState(() => _recipient = member);
                        },
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(
                    _recipient == null
                        ? 'Pesquisar e escolher membro'
                        : _recipient!['name'] as String,
                  ),
                ),
                if (_recipient != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'ID: ' + (_recipient!['user_id'] as String),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.pbhColors.textTertiary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Reconhecimento especial',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Escolha o selo que representa a contribuição do membro.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.pbhColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in labels.entries) ...[
                  _badgeOption(item.key, item.value),
                  const SizedBox(height: 10),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.pbhColors.backgroundElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: context.pbhColors.textTertiary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Os selos de progresso são automáticos e podem ser antecipados pelo líder. Remover uma concessão manual preserva o progresso conquistado. Platina e Rubi continuam vinculados aos desafios.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: context.pbhColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _save(true),
                  icon: const Icon(Icons.add_moderator_outlined),
                  label: Text(_busy ? 'Salvando...' : 'Conceder selo'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _save(false),
                  icon: const Icon(Icons.remove_moderator_outlined),
                  label: const Text('Remover selo'),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Selos concedidos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  enabled: !_awardsLoading,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _loadAwards(reset: true),
                  decoration: InputDecoration(
                    hintText: 'Buscar nome ou e-mail',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar',
                      onPressed: _awardsLoading
                          ? null
                          : () => _loadAwards(reset: true),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final award in _awards)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.shield_outlined,
                        color: context.pbhColors.orange,
                      ),
                      title: Text(award['name'] as String),
                      subtitle: Text(
                        (labels[award['badge_key']] ??
                                award['badge_key'] as String) +
                            '\n' +
                            (award['email'] as String),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Remover selo',
                        onPressed: _busy
                            ? null
                            : () {
                                _recipient = {
                                  'user_id': award['user_id'],
                                  'name': award['name'],
                                };
                                setState(
                                  () => _badge = award['badge_key'] as String,
                                );
                                _save(false);
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ),
                  ),
                if (_awardsLoading)
                  const Center(child: CircularProgressIndicator()),
                if (_awardsError != null)
                  TextButton(
                    onPressed: () => _loadAwards(reset: true),
                    child: Text(_awardsError!),
                  ),
                if (!_awardsLoading && _awardsError == null && _awards.isEmpty)
                  const Text('Nenhum selo encontrado.'),
                if (!_awardsLoading &&
                    _awardsError == null &&
                    _more &&
                    _awards.isNotEmpty)
                  TextButton(
                    onPressed: () => _loadAwards(),
                    child: const Text('Carregar mais'),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!),
                  ),
              ],
            ),
          ),
  );
}
