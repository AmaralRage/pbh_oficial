import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/announcement_service.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  static const _templates = <({String label, String title, String message})>[
    (label: 'Motivação', title: 'Um passo de cada vez', message: 'A constância se constrói nas pequenas escolhas de hoje. Continue firme na sua jornada.'),
    (label: 'Novo desafio', title: 'Tem desafio novo na comunidade', message: 'Prepare-se para sair da zona de conforto. Confira a área de desafios e dê o próximo passo.'),
    (label: 'Conquista coletiva', title: 'Nossa comunidade está avançando', message: 'Cada compromisso cumprido inspira alguém. Obrigado por fazer parte dessa caminhada.'),
    (label: 'Aviso importante', title: 'Aviso importante', message: 'Temos uma atualização para compartilhar com você. Acesse o app para conferir os detalhes.'),
    (label: 'Boas-vindas', title: 'Que bom ter você aqui', message: 'Sua jornada começa com uma escolha. Explore o PBH e dê hoje o primeiro passo.'),
    (label: 'Lembrete', title: 'Seu compromisso de hoje', message: 'Reserve alguns minutos para cumprir sua meta de hoje. Pequenas ações constroem grandes mudanças.'),
  ];

  static const _tabs = ['Nova notificação', 'Histórico', 'Rascunhos', 'Modelos'];
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _urlController = TextEditingController();
  final _searchController = TextEditingController();
  final _service = AnnouncementService();
  List<Announcement> _announcements = const [];
  List<AnnouncementDraft> _drafts = const [];
  AnnouncementMetrics? _metrics;
  int _tab = 0;
  bool _loading = true;
  bool _sending = false;
  bool _savingDraft = false;
  bool _soundEnabled = true;
  bool _previewAndroid = false;
  String _audience = 'all';
  String? _editingDraftId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([
        _service.fetchMetrics(),
        _service.fetchAnnouncements(limit: 50, includeAudienceMetrics: true),
        _service.fetchDrafts(),
      ]);
      if (!mounted) return;
      setState(() {
        _metrics = values[0] as AnnouncementMetrics;
        _announcements = values[1] as List<Announcement>;
        _drafts = values[2] as List<AnnouncementDraft>;
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = _friendlyError(error); });
    }
  }

  String _friendlyError(Object error) {
    final details = error.toString();
    final normalized = details.toLowerCase();
    if ((normalized.contains('announcements.audience') && normalized.contains('does not exist')) ||
        normalized.contains('column "audience" of relation "announcements" does not exist')) {
      return 'O banco ainda não recebeu a migration da central profissional. No Supabase, execute o conteúdo completo de supabase/migrations/20261015000400_admin_notification_center.sql. Depois atualize esta tela.';
    }
    if (normalized.contains('announcement_drafts') &&
        (normalized.contains('does not exist') || normalized.contains('schema cache'))) {
      return 'A tabela de rascunhos ainda não existe. Execute supabase/migrations/20261015000400_admin_notification_center.sql no Supabase.';
    }
    if (normalized.contains('admin_announcement_metrics') &&
        (normalized.contains('pgrst202') || normalized.contains('schema cache') || normalized.contains('does not exist'))) {
      return 'As funções de métricas ainda não existem. Execute supabase/migrations/20261015000400_admin_notification_center.sql no Supabase.';
    }
    return details;
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
      return 'Informe um link completo começando com https://';
    }
    return null;
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final id = await _service.publish(
        title: _titleController.text,
        message: _messageController.text,
        audience: _audience,
        destinationUrl: _urlController.text,
        soundEnabled: _soundEnabled,
      );
      String? pushWarning;
      var pushSent = 0;
      try {
        pushSent = await _service.sendPush(announcementId: id);
      } catch (error) {
        pushWarning = 'O aviso já está na central do app, mas o push não pôde ser enviado: $error';
      }
      if (!mounted) return;
      _clearForm();
      await _load();
      if (mounted) await _showPublishedAnimation(pushWarning, pushSent);
    } catch (error) {
      _showMessage('Não foi possível publicar: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingDraft = true);
    try {
      await _service.saveDraft(
        id: _editingDraftId,
        title: _titleController.text,
        message: _messageController.text,
        audience: _audience,
        destinationUrl: _urlController.text,
        soundEnabled: _soundEnabled,
      );
      _clearForm();
      await _load();
      if (mounted) {
        setState(() => _tab = 2);
        _showMessage('Rascunho salvo na sua conta.');
      }
    } catch (error) {
      _showMessage('Não foi possível salvar o rascunho: ${_errorText(error)}');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _messageController.clear();
    _urlController.clear();
    _audience = 'all';
    _soundEnabled = true;
    _editingDraftId = null;
    FocusScope.of(context).unfocus();
  }

  void _loadDraft(AnnouncementDraft draft) {
    setState(() {
      _titleController.text = draft.title;
      _messageController.text = draft.message;
      _urlController.text = draft.destinationUrl ?? '';
      _audience = draft.audience;
      _soundEnabled = draft.soundEnabled;
      _editingDraftId = draft.id;
      _tab = 0;
    });
  }

  void _useTemplate(({String label, String title, String message}) template) {
    setState(() {
      _titleController.text = template.title;
      _messageController.text = template.message;
      _editingDraftId = null;
      _tab = 0;
    });
  }

  Future<void> _deleteDraft(AnnouncementDraft draft) async {
    try {
      await _service.deleteDraft(draft.id);
      await _load();
    } catch (error) {
      _showMessage('Não foi possível excluir: ${_errorText(error)}');
    }
  }

  String _errorText(Object error) => error is PostgrestException ? error.message : error.toString();

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
  }

  Future<void> _showPublishedAnimation(String? pushWarning, int pushSent) => showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Notificação publicada',
        barrierColor: Colors.black.withOpacity(.72),
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (context, animation, secondaryAnimation) => _AnnouncementSuccessDialog(pushWarning: pushWarning, pushSent: pushSent),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
          return FadeTransition(opacity: animation, child: ScaleTransition(scale: curve, child: child));
        },
      );

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Agora';
    if (difference.inHours < 1) return 'Há ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Há ${difference.inHours} h';
    if (difference.inDays < 7) return 'Há ${difference.inDays} d';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<Announcement> get _filteredHistory {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _announcements;
    return _announcements.where((item) => item.title.toLowerCase().contains(query) || item.message.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 950;
          final horizontalInset = wide ? 30.0 : 18.0;
          final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 1280.0;
          final contentWidth = (availableWidth - horizontalInset * 2).clamp(1.0, 1280.0).toDouble();
          final content = <Widget>[
            _pageHeading(),
            const SizedBox(height: 24),
            if (_loading && _metrics == null)
              const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _metrics == null)
              _errorPanel()
            else ...[
              _metricsGrid(contentWidth),
              const SizedBox(height: 32),
              _buildTabs(),
              const SizedBox(height: 24),
              if (_tab == 0) _composerLayout(wide, contentWidth)
              else if (_tab == 1) _historyPanel()
              else if (_tab == 2) _draftPanel()
              else _templatesPanel(),
              if (_tab == 0) ...[
                const SizedBox(height: 28),
                _recentSection(),
              ],
            ],
          ];
          return RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontalInset, 18, horizontalInset, 36),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
                ),
              ),
            ),
          );
        }),
      );

  Widget _pageHeading() => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Central de notificações', style: AppTextStyles.headline),
          const SizedBox(height: 5),
          Text('Conecte-se com seus usuários no momento certo.', style: AppTextStyles.bodySmall),
        ])),
        IconButton.filledTonal(tooltip: 'Atualizar dados', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]);
  Widget _metricsGrid(double width) {
    final metrics = _metrics;
    if (metrics == null || width <= 0) return const SizedBox.shrink();
    final count = width >= 1100 ? 4 : width >= 350 ? 2 : 1;
    const spacing = 12.0;
    final items = <Widget>[
      _MetricCard(icon: Icons.send_rounded, title: 'Notificações enviadas', value: '${metrics.sent}', detail: 'Últimos 30 dias'),
      _MetricCard(icon: Icons.verified_rounded, title: 'Taxa de envio push', value: metrics.pushDeliveryRate == null ? '—' : '${metrics.pushDeliveryRate!.toStringAsFixed(1)}%', detail: '${metrics.pushAccepted} de ${metrics.pushAttempted} dispositivos aceitos'),
      _MetricCard(icon: Icons.mark_email_read_outlined, title: 'Taxa de leitura', value: metrics.readRate == null ? '—' : '${metrics.readRate!.toStringAsFixed(1)}%', detail: '${metrics.readReceipts} confirmações de leitura'),
      _MetricCard(icon: Icons.groups_2_outlined, title: 'Público cadastrado', value: '${_audienceCountFor(metrics)}', detail: '${metrics.registeredUsers} contas no total'),
    ];
    final rows = <Widget>[];
    for (var start = 0; start < items.length; start += count) {
      final end = (start + count).clamp(0, items.length);
      final rowItems = <Widget>[];
      for (var index = start; index < end; index++) {
        if (rowItems.isNotEmpty) rowItems.add(const SizedBox(width: spacing));
        rowItems.add(Expanded(child: items[index]));
      }
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowItems));
      if (end < items.length) rows.add(const SizedBox(height: spacing));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
  Widget _buildTabs() => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
        child: Wrap(
          spacing: 8,
          runSpacing: 2,
          children: List.generate(_tabs.length, (index) {
            final selected = index == _tab;
            return InkWell(
              onTap: () => setState(() => _tab = index),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? AppColors.orange : Colors.transparent, width: 2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_tabs[index], style: AppTextStyles.chip.copyWith(color: selected ? AppColors.orange : AppColors.textSecondary)),
                  if (index == 2 && _drafts.isNotEmpty) ...[const SizedBox(width: 7), _CountBadge(count: _drafts.length)],
                ]),
              ),
            );
          }),
        ),
      );
  Widget _composerLayout(bool wide, double width) {
    final form = _composerCard();
    final preview = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _previewCard(),
      const SizedBox(height: 14),
      _tipCard(),
    ]);
    if (!wide) {
      return SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [form, const SizedBox(height: 16), preview],
        ),
      );
    }
    return SizedBox(
      width: width,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 7, child: form),
        const SizedBox(width: 18),
        Expanded(flex: 4, child: preview),
      ]),
    );
  }

  Widget _composerCard() => _Panel(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _IconTile(icon: Icons.campaign_outlined),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_editingDraftId == null ? 'Criar nova notificação' : 'Editar rascunho', style: AppTextStyles.titleMedium),
                const SizedBox(height: 3),
                Text('A mensagem será publicada na central dos usuários selecionados.', style: AppTextStyles.bodySmall),
              ])),
              const _AdminBadge(),
            ]),
            const SizedBox(height: 20),
            _SectionTitle(number: '1', title: 'Conteúdo da mensagem'),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Título *', hintText: 'Ex.: Tem novidade esperando por você', helperText: 'Seja breve e desperte a curiosidade.'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Informe o título.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _messageController,
              minLines: 4,
              maxLines: 7,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Mensagem *', hintText: 'Converse com seus usuários de forma natural.', alignLabelWithHint: true),
              validator: (value) => value == null || value.trim().isEmpty ? 'Escreva a mensagem.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Link de destino (opcional)', hintText: 'https://seusite.com/novidades', prefixIcon: Icon(Icons.link_rounded)),
              validator: _validateUrl,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 14),
            _SectionTitle(number: '2', title: 'Quem vai receber?'),
            const SizedBox(height: 12),
            _audienceOptions(),
            const SizedBox(height: 9),
            Row(children: [
              const Icon(Icons.groups_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text('Estimativa: ${_audienceCount()} contas cadastradas poderão ver o aviso.', style: AppTextStyles.statLabel)),
            ]),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 14),
            _SectionTitle(number: '3', title: 'Quando enviar?'),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.radio_button_checked_rounded, color: AppColors.orange, size: 18),
              const SizedBox(width: 8),
              Text('Enviar agora', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
              const SizedBox(width: 20),
              Icon(Icons.schedule_rounded, color: AppColors.textTertiary, size: 17),
              const SizedBox(width: 7),
              Expanded(child: Text('Agendamento requer rotina de envio no Supabase.', style: AppTextStyles.statLabel)),
            ]),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, constraints) {
              final actions = [
                TextButton.icon(onPressed: _sending || _savingDraft ? null : _saveDraft, icon: const Icon(Icons.save_outlined, size: 17), label: Text(_savingDraft ? 'Salvando...' : 'Salvar rascunho')),
                ElevatedButton.icon(onPressed: _sending || _savingDraft ? null : _publish, icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 17), label: Text(_sending ? 'Enviando...' : 'Enviar notificação')),
              ];
              if (constraints.maxWidth < 590) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [const Icon(Icons.shield_outlined, size: 15, color: AppColors.textTertiary), const SizedBox(width: 6), Expanded(child: Text('Envio seguro para o público selecionado.', style: AppTextStyles.statLabel))]),
                  const SizedBox(height: 8),
                  Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: actions),
                ]);
              }
              return Row(children: [
                const Icon(Icons.shield_outlined, size: 15, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(child: Text('Envio seguro para o público selecionado.', style: AppTextStyles.statLabel)),
                ...actions,
              ]);
            }),
          ]),
        ),
      );

  Widget _audienceOptions() => LayoutBuilder(builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 570;
        final options = [
          _AudienceOption(title: 'Todos os usuários', subtitle: 'Alcance toda a base', icon: Icons.groups_2_outlined, selected: _audience == 'all', onTap: () => setState(() => _audience = 'all')),
          _AudienceOption(title: 'Membros', subtitle: 'Contas sem papel administrativo', icon: Icons.person_outline, selected: _audience == 'members', onTap: () => setState(() => _audience = 'members')),
          _AudienceOption(title: 'Administradores', subtitle: 'Somente contas administrativas', icon: Icons.admin_panel_settings_outlined, selected: _audience == 'admins', onTap: () => setState(() => _audience = 'admins')),
        ];
        if (!horizontal) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: options.map((option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: option,
            )).toList(),
          );
        }
        return Wrap(spacing: 9, runSpacing: 9, children: options.map((option) => SizedBox(width: (constraints.maxWidth - 9) / 2, child: option)).toList());
      });

  int _audienceCount() {
    final metrics = _metrics;
    if (metrics == null) return 0;
    return _audienceCountFor(metrics);
  }

  int _audienceCountFor(AnnouncementMetrics metrics) => switch (_audience) {
        'members' => metrics.memberUsers,
        'admins' => metrics.adminUsers,
        _ => metrics.registeredUsers,
      };

  Widget _previewCard() {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text('Prévia da notificação', style: AppTextStyles.titleMedium)), _LiveBadge()]),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('iOS'), icon: Icon(Icons.phone_iphone_rounded)),
            ButtonSegment(value: true, label: Text('Android'), icon: Icon(Icons.phone_android_rounded)),
          ],
          selected: {_previewAndroid},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => setState(() => _previewAndroid = selection.first),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final phoneWidth = (constraints.maxWidth - 28).clamp(1.0, 270.0).toDouble();
          return Center(child: _PhoneNotificationPreview(
            width: phoneWidth,
            android: _previewAndroid,
            title: title.isEmpty ? 'O título aparecerá aqui' : title,
            message: message.isEmpty ? 'A prévia da sua mensagem aparece aqui enquanto você escreve.' : message,
            destinationUrl: _urlController.text.trim(),
          ));
        }),
        const SizedBox(height: 14),
        Text(_previewAndroid ? 'Aparência aproximada em um celular Android.' : 'iPhone 16 · iOS 18', textAlign: TextAlign.center, style: AppTextStyles.statLabel),
        const Divider(height: 24),
        Row(children: [
          const Icon(Icons.volume_up_outlined, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Som da notificação', style: AppTextStyles.titleMedium.copyWith(fontSize: 13)),
            Text('Som no app aberto; no navegador, o dispositivo controla o áudio.', style: AppTextStyles.statLabel),
          ])),
          Switch(value: _soundEnabled, onChanged: (value) => setState(() => _soundEnabled = value)),
        ]),
      ]),
    );
  }

  Widget _tipCard() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.orange.withOpacity(.18))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_awesome_outlined, color: AppColors.orange, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pequenos detalhes, grandes resultados', style: _AdminTextStyles.tipTitle),
            const SizedBox(height: 4),
            Text('Mensagens curtas e personalizadas facilitam a leitura. Confira o público e a prévia antes de enviar.', style: _AdminTextStyles.tipBody),
          ])),
        ]),
      );

  Widget _recentSection() {
    final items = _announcements.take(5).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text('Últimas notificações', style: AppTextStyles.titleMedium)), TextButton(onPressed: () => setState(() => _tab = 1), child: const Text('Ver histórico completo  →'))]),
      const SizedBox(height: 10),
      if (items.isEmpty) _emptyPanel('Suas notificações enviadas aparecerão aqui.') else ...items.map(_historyRow),
    ]);
  }

  Widget _historyPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Todas as notificações', style: AppTextStyles.titleMedium), const SizedBox(height: 4), Text('${_filteredHistory.length} notificações', style: AppTextStyles.bodySmall)])), const SizedBox(width: 12), SizedBox(width: 260, child: TextField(controller: _searchController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Buscar notificação', prefixIcon: Icon(Icons.search_rounded), isDense: true))) ]),
        const SizedBox(height: 16),
        if (_filteredHistory.isEmpty) _emptyPanel(_searchController.text.isEmpty ? 'Ainda não há notificações publicadas.' : 'Nenhuma notificação corresponde à busca.') else ..._filteredHistory.map(_historyRow),
      ]);

  Widget _historyRow(Announcement item) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _IconTile(icon: Icons.notifications_none_rounded, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(item.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
            const SizedBox(height: 7),
            Wrap(spacing: 9, runSpacing: 5, children: [
              _SmallLabel(text: _audienceLabel(item.audience)),
              _SmallLabel(text: _relativeTime(item.createdAt)),
              if (item.pushAttempted > 0) _SmallLabel(text: 'Push aceito ${item.pushAccepted}/${item.pushAttempted}'),
              _SmallLabel(text: '${item.readCount} leituras no app'),
            ]),
          ])),
        ]),
      );

  Widget _draftPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text('Rascunhos salvos', style: AppTextStyles.titleMedium)), Text('${_drafts.length}', style: AppTextStyles.bodySmall)]),
        const SizedBox(height: 12),
        if (_drafts.isEmpty) _emptyPanel('Salve uma mensagem para continuar editando depois.') else ..._drafts.map((draft) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
              child: Row(children: [
                _IconTile(icon: Icons.drafts_outlined, size: 38),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(draft.title, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)), const SizedBox(height: 3), Text('${_audienceLabel(draft.audience)} · atualizado ${_relativeTime(draft.updatedAt)}', style: AppTextStyles.statLabel)])),
                IconButton(tooltip: 'Editar rascunho', onPressed: () => _loadDraft(draft), icon: const Icon(Icons.edit_outlined)),
                IconButton(tooltip: 'Excluir rascunho', onPressed: () => _deleteDraft(draft), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary)),
              ]),
            )),
      ]);

  Widget _templatesPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Modelos prontos', style: AppTextStyles.titleMedium),
        const SizedBox(height: 5),
        Text('Escolha um ponto de partida e personalize antes de enviar.', style: AppTextStyles.bodySmall),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 750 ? 2 : 1;
          final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: _templates.map((template) => SizedBox(width: width, child: _TemplateCard(template: template, onUse: () => _useTemplate(template)))).toList());
        }),
      ]);

  Widget _errorPanel() => _Panel(child: Column(children: [const Icon(Icons.cloud_off_outlined, color: AppColors.orange, size: 30), const SizedBox(height: 9), Text('Não foi possível carregar a central.', style: AppTextStyles.titleMedium), const SizedBox(height: 6), Text(_error ?? '', style: AppTextStyles.bodySmall, textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar novamente'))]));

  Widget _emptyPanel(String message) => _Panel(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Column(children: [const Icon(Icons.notifications_none_rounded, color: AppColors.textTertiary, size: 30), const SizedBox(height: 8), Text(message, style: AppTextStyles.bodySmall, textAlign: TextAlign.center)])));

  String _audienceLabel(String value) => switch (value) { 'members' => 'Membros', 'admins' => 'Administradores', _ => 'Todos os usuários' };
}

class _PhoneNotificationPreview extends StatelessWidget {
  const _PhoneNotificationPreview({
    required this.width,
    required this.android,
    required this.title,
    required this.message,
    required this.destinationUrl,
  });

  final double width;
  final bool android;
  final String title;
  final String message;
  final String destinationUrl;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.92;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFF090B0A),
        borderRadius: BorderRadius.circular(width * .15),
        border: Border.all(color: const Color(0xFF505451), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.42), blurRadius: 24, offset: const Offset(0, 14)),
          BoxShadow(color: AppColors.orange.withOpacity(.08), blurRadius: 28, spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * .12),
        child: Stack(fit: StackFit.expand, children: [
          const _PhoneWallpaper(),
          Padding(
            padding: EdgeInsets.fromLTRB(width * .075, height * .045, width * .075, height * .045),
            child: Column(children: [
              Row(children: [
                Text('9:41', style: TextStyle(color: Colors.white, fontSize: width * .038, fontWeight: FontWeight.w700)),
                const Spacer(),
                Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: width * .045),
                SizedBox(width: width * .018),
                Icon(Icons.wifi_rounded, color: Colors.white, size: width * .045),
                SizedBox(width: width * .018),
                Icon(Icons.battery_full_rounded, color: Colors.white, size: width * .05),
              ]),
              SizedBox(height: height * .105),
              Text('Quinta-feira, 15 de outubro', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(.94), fontSize: width * .038, fontWeight: FontWeight.w600)),
              SizedBox(height: height * .005),
              Text('9:41', style: TextStyle(color: Colors.white, fontSize: width * .19, height: 1, fontWeight: FontWeight.w300, letterSpacing: -2, shadows: const [Shadow(color: Colors.black26, blurRadius: 10)])),
              SizedBox(height: height * .012),
              Icon(Icons.lock_outline_rounded, color: Colors.white.withOpacity(.9), size: width * .05),
              SizedBox(height: height * .055),
              _phoneNotification(width),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _lockScreenButton(Icons.flashlight_on_outlined, width),
                _lockScreenButton(Icons.photo_camera_outlined, width),
              ]),
              SizedBox(height: height * .018),
              Container(width: width * .36, height: 4, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
            ]),
          ),
          Positioned(
            top: height * .018,
            left: 0,
            right: 0,
            child: Center(child: Container(
              width: android ? width * .12 : width * .34,
              height: width * .075,
              decoration: BoxDecoration(color: const Color(0xFF050606), borderRadius: BorderRadius.circular(30)),
            )),
          ),
        ]),
      ),
    );
  }

  Widget _phoneNotification(double phoneWidth) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(phoneWidth * .045),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4EF).withOpacity(.96),
          borderRadius: BorderRadius.circular(phoneWidth * .065),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: phoneWidth * .13,
            height: phoneWidth * .13,
            decoration: BoxDecoration(color: const Color(0xFF126447), borderRadius: BorderRadius.circular(phoneWidth * .035)),
            child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: phoneWidth * .085),
          ),
          SizedBox(width: phoneWidth * .035),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('PBH OFICIAL', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: const Color(0xFF25312C), fontSize: phoneWidth * .032, fontWeight: FontWeight.w800, letterSpacing: .25))),
              Text('agora', style: TextStyle(color: const Color(0xFF67736C), fontSize: phoneWidth * .029)),
            ]),
            SizedBox(height: phoneWidth * .018),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: const Color(0xFF17211C), fontSize: phoneWidth * .041, height: 1.16, fontWeight: FontWeight.w700)),
            SizedBox(height: phoneWidth * .018),
            Text(message, maxLines: 4, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: const Color(0xFF3E4A44), fontSize: phoneWidth * .034, height: 1.25)),
            if (destinationUrl.isNotEmpty) ...[
              SizedBox(height: phoneWidth * .018),
              Text(destinationUrl, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: const Color(0xFF126447), fontSize: phoneWidth * .03)),
            ],
          ])),
        ]),
      );

  Widget _lockScreenButton(IconData icon, double phoneWidth) => Container(
        width: phoneWidth * .16,
        height: phoneWidth * .16,
        decoration: BoxDecoration(color: Colors.white.withOpacity(.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.24))),
        child: Icon(icon, color: Colors.white, size: phoneWidth * .07),
      );
}

class _PhoneWallpaper extends StatelessWidget {
  const _PhoneWallpaper();

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB8EBC2), Color(0xFF08734B), Color(0xFF063D2E), Color(0xFF43A66A)]))),
        Positioned(left: -70, top: 100, child: Transform.rotate(angle: -.58, child: Container(width: 240, height: 95, decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), gradient: const LinearGradient(colors: [Color(0xFFE2FFE0), Color(0xFF58C77A), Color(0xFF087249)]), boxShadow: [BoxShadow(color: Colors.white.withOpacity(.26), blurRadius: 24, spreadRadius: 4)])))),
        Positioned(right: -100, top: 185, child: Transform.rotate(angle: .64, child: Container(width: 270, height: 115, decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), gradient: const LinearGradient(colors: [Color(0xFFB9F2B7), Color(0xFF138556), Color(0xFF06432F)]), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 20, spreadRadius: 2)])))),
        Positioned(left: -65, bottom: 65, child: Transform.rotate(angle: .55, child: Container(width: 240, height: 100, decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), gradient: const LinearGradient(colors: [Color(0xFF0B5D3D), Color(0xFF9AE3A1), Color(0xFF1A8A58)]))))),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x12000000), Color(0x44000000)]))),
      ]);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.title, required this.value, required this.detail});
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: AppTextStyles.bodySmall)), _IconTile(icon: icon, size: 34)]),
          const SizedBox(height: 13),
          Text(value, style: AppTextStyles.displayLarge.copyWith(fontSize: 27)),
          const SizedBox(height: 5),
          Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.statLabel),
        ]),
      );
}

class _AudienceOption extends StatelessWidget {
  const _AudienceOption({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: selected ? AppColors.orangeDim : AppColors.background, borderRadius: BorderRadius.circular(13), border: Border.all(color: selected ? AppColors.orange.withOpacity(.65) : AppColors.borderSubtle)),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? AppColors.orange : AppColors.textTertiary, size: 18),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 13)), const SizedBox(height: 3), Text(subtitle, style: AppTextStyles.statLabel)])),
            Icon(icon, size: 17, color: selected ? AppColors.orange : AppColors.textTertiary),
          ]),
        ),
      );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onUse});
  final ({String label, String title, String message}) template;
  final VoidCallback onUse;
  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [_IconTile(icon: Icons.bolt_rounded, size: 36), const SizedBox(width: 10), Expanded(child: Text(template.label, style: _AdminTextStyles.templateLabel))]),
          const SizedBox(height: 12),
          Text(template.title, style: AppTextStyles.titleMedium),
          const SizedBox(height: 5),
          Text(template.message, style: AppTextStyles.bodySmall),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onUse, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Usar modelo'))),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(padding: padding, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderSubtle)), child: child);
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.size = 44});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.orange, size: size * .48));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});
  final String number;
  final String title;
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 23, height: 23, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border)), child: Text(number, style: AppTextStyles.statLabel)), const SizedBox(width: 8), Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 14))]);
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(30)), child: Text('ADMIN', style: AppTextStyles.eyebrow.copyWith(fontSize: 9)));
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.circle, size: 6, color: AppColors.orange), const SizedBox(width: 5), Text('AO VIVO', style: AppTextStyles.eyebrow.copyWith(fontSize: 8))]));
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderSubtle)), child: Text(text, style: AppTextStyles.statLabel.copyWith(fontSize: 9)));
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)), child: Text('$count', style: AppTextStyles.statLabel.copyWith(color: AppColors.orange)));
}

class _AdminTextStyles {
  static TextStyle get tipTitle => AppTextStyles.titleMedium.copyWith(fontSize: 13, color: AppColors.textPrimary);
  static TextStyle get tipBody => AppTextStyles.bodySmall.copyWith(fontSize: 11);
  static TextStyle get templateLabel => AppTextStyles.chip.copyWith(color: AppColors.orange);
}

class _AnnouncementSuccessDialog extends StatefulWidget {
  const _AnnouncementSuccessDialog({this.pushWarning, required this.pushSent});
  final String? pushWarning;
  final int pushSent;
  @override
  State<_AnnouncementSuccessDialog> createState() => _AnnouncementSuccessDialogState();
}

class _AnnouncementSuccessDialogState extends State<_AnnouncementSuccessDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 22), child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(animation: _controller, builder: (context, child) => Transform.rotate(angle: (1 - _controller.value) * -.08, child: Transform.scale(scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut).value, child: child)), child: Container(width: 86, height: 86, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.orangeDim, border: Border.all(color: AppColors.orange.withOpacity(.6)), boxShadow: [BoxShadow(color: AppColors.orange.withOpacity(.2), blurRadius: 26)]), child: const Icon(Icons.campaign_rounded, color: AppColors.orange, size: 42))),
          const SizedBox(height: 20),
          Text('Notificação enviada!', style: AppTextStyles.headline, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(widget.pushWarning ?? (widget.pushSent == 0 ? 'O aviso está na central do app. Nenhum navegador inscrito recebeu push.' : 'A central foi atualizada e ${widget.pushSent} navegador(es) aceitaram o push.'), textAlign: TextAlign.center, style: AppTextStyles.body),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continuar'))),
        ])),
      );
}
