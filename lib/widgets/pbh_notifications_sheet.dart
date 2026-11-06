import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/announcement_service.dart';
import 'support_reply_notice.dart';
import 'loading_cards.dart';
import 'connection_notice.dart';
import '../services/community_post_navigation.dart';
import '../screens/community_publication_screen.dart';

class PbhNotificationsSheet extends StatefulWidget {
  const PbhNotificationsSheet({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<PbhNotificationsSheet> createState() => _PbhNotificationsSheetState();
}

class _PbhNotificationsSheetState extends State<PbhNotificationsSheet> {
  final _service = AnnouncementService();
  List<Announcement> _announcements = const [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _markingAll = false;
  bool _unreadOnly = false;
  String? _error;
  int _supportUnread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _channel = Supabase.instance.client
        .channel('announcement-sheet-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final announcements = await _service.fetchAnnouncements();
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
        _loading = false;
        _error = null;
      });
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar as notificações.';
        });
      }
    }
  }

  Future<void> _markRead(Announcement item) async {
    if (item.isRead) return;
    try {
      await _service.markRead(item.id);
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar a notificação.'),
          ),
        );
      }
    }
  }

  Future<void> _openNotification(Announcement item) async {
    await _markRead(item);
    final destination = item.destinationUrl;
    if (destination == null || destination.trim().isEmpty) return;
    final post = communityPostFromNotificationUrl(destination);
    if (post != null) {
      if (mounted)
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityPublicationScreen(postId: post),
          ),
        );
      return;
    }
    final uri = Uri.tryParse(destination);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link desta notificação.'),
          ),
        );
      }
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      for (final item in _announcements.where((item) => !item.isRead)) {
        await _service.markRead(item.id);
      }
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível atualizar as notificações.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Agora';
    if (difference.inHours < 1) return 'Há ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Há ${difference.inHours} h';
    if (difference.inDays < 7) return 'Há ${difference.inDays} d';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final generalUnread = _announcements.where((item) => !item.isRead).length;
    final unreadCount = generalUnread + _supportUnread;
    final visible = _unreadOnly
        ? _announcements.where((item) => !item.isRead).toList()
        : _announcements;
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * .82,
        decoration: BoxDecoration(
          color: context.pbhColors.backgroundElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: context.pbhColors.inactive,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.pbhColors.orangeDim,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: context.pbhColors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notificações',
                          style: AppTextStyles.headline.copyWith(fontSize: 21),
                        ),
                        Text(
                          unreadCount == 0
                              ? 'Você está em dia'
                              : '$unreadCount ${unreadCount == 1 ? 'aviso novo' : 'avisos novos'}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (generalUnread > 0)
                    IconButton(
                      tooltip: 'Marcar todas como lidas',
                      onPressed: _markingAll ? null : _markAllRead,
                      icon: _markingAll
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.done_all_rounded,
                              color: context.pbhColors.orange,
                            ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'Todas',
                    selected: !_unreadOnly,
                    onTap: () => setState(() => _unreadOnly = false),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Não lidas',
                    count: unreadCount,
                    selected: _unreadOnly,
                    onTap: () => setState(() => _unreadOnly = true),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SupportReplyNotice(
              onChanged: () => widget.onChanged?.call(),
              onCountChanged: (count) {
                if (mounted) setState(() => _supportUnread = count);
              },
            ),
            if (_error != null && _announcements.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ConnectionNotice(
                  message:
                      'Não foi possível atualizar. Os avisos já carregados continuam disponíveis.',
                  onRetry: _refresh,
                ),
              ),
            Expanded(
              child: _loading
                  ? const SingleChildScrollView(
                      padding: EdgeInsets.all(18),
                      child: LoadingCards(
                        count: 3,
                        showMedia: false,
                        label: 'Carregando avisos',
                      ),
                    )
                  : _error != null && _announcements.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: ConnectionNotice(onRetry: _refresh),
                    )
                  : visible.isEmpty
                  ? _EmptyNotifications(
                      icon: _unreadOnly
                          ? Icons.done_all_rounded
                          : Icons.notifications_none_rounded,
                      title: _unreadOnly
                          ? 'Tudo foi lido'
                          : 'Nenhum aviso por enquanto',
                      subtitle: _unreadOnly
                          ? 'Novos avisos aparecerão aqui.'
                          : 'Quando houver novidades, você as verá aqui.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(item.id),
                          duration: Duration(milliseconds: 260 + index * 35),
                          tween: Tween(begin: 0, end: 1),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - value)),
                              child: child,
                            ),
                          ),
                          child: _NotificationCard(
                            item: item,
                            time: _relativeTime(item.createdAt),
                            onTap: () => _openNotification(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
  });

  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? context.pbhColors.orangeDim : context.pbhColors.surface,
    borderRadius: BorderRadius.circular(30),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? context.pbhColors.orange.withOpacity(.5)
                : context.pbhColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.chip.copyWith(
                color: selected
                    ? context.pbhColors.orange
                    : context.pbhColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: AppTextStyles.chip.copyWith(
                  color: context.pbhColors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.pbhColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.pbhColors.textTertiary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.time,
    required this.onTap,
  });

  final Announcement item;
  final String time;
  final VoidCallback onTap;
  bool get _community =>
      communityPostFromNotificationUrl(item.destinationUrl) != null;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    decoration: BoxDecoration(
      color: item.isRead
          ? context.pbhColors.surface.withOpacity(.55)
          : context.pbhColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: item.isRead
            ? context.pbhColors.borderSubtle
            : context.pbhColors.border,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _community
                      ? AppColors.orange
                      : context.pbhColors.orangeDim,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _community ? Icons.groups_rounded : Icons.campaign_outlined,
                  color: _community ? Colors.white : context.pbhColors.orange,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_community) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Comunidade',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: AppTextStyles.statLabel.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            margin: const EdgeInsets.only(top: 5, left: 8),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: context.pbhColors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(item.message, style: AppTextStyles.bodySmall),
                    if (!_community) ...[
                      const SizedBox(height: 9),
                      Text(
                        time,
                        style: AppTextStyles.statLabel.copyWith(fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
