import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class CommunityIdentity {
  const CommunityIdentity(this.name, this.avatarUrl, this.founder);
  final String name;
  final String? avatarUrl;
  final bool founder;
}

/// Refreshes mounted identities without granting access to the profiles table.
class CommunityIdentityBuilder extends StatefulWidget {
  const CommunityIdentityBuilder({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.client,
    required this.builder,
  });
  final String userId, name;
  final String? avatarUrl;
  final SupabaseClient? client;
  final Widget Function(BuildContext, CommunityIdentity) builder;
  @override
  State<CommunityIdentityBuilder> createState() =>
      _CommunityIdentityBuilderState();
}

class _CommunityIdentityBuilderState extends State<CommunityIdentityBuilder>
    with WidgetsBindingObserver {
  static final _requests = <String, ({DateTime at, Future<dynamic> value})>{};
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _auth;
  Timer? _timer;
  CommunityIdentity? _identity;
  bool _loading = false;
  int _generation = 0;
  String? _viewer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _client = widget.client ?? Supabase.instance.client;
    } catch (_) {}
    _viewer = _client?.auth.currentUser?.id;
    _auth = _client?.auth.onAuthStateChange.listen((_) {
      final viewer = _client?.auth.currentUser?.id;
      if (viewer != _viewer) {
        _viewer = viewer;
        _generation++;
        _identity = null;
      }
      if (mounted) setState(() {});
      _refresh();
    });
    if (_client != null &&
        RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(widget.userId)) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    }
    _refresh();
  }

  Future<void> _refresh() async {
    final client = _client;
    if (_loading ||
        client == null ||
        client.auth.currentUser?.id == widget.userId ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(widget.userId) ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed))
      return;
    _loading = true;
    final generation = _generation;
    try {
      final now = DateTime.now();
      _requests.removeWhere(
        (_, request) => now.difference(request.at) > const Duration(seconds: 2),
      );
      final key =
          '${identityHashCode(client)}:${client.auth.currentUser?.id}:${widget.userId}';
      final request = _requests.putIfAbsent(
        key,
        () => (
          at: now,
          value: client
              .rpc(
                'community_member_identities',
                params: {
                  'p_ids': [widget.userId],
                },
              )
              .timeout(const Duration(seconds: 10)),
        ),
      );
      final rows = await request.value;
      if (!mounted || generation != _generation) return;
      final row = (rows as List).isEmpty ? null : rows.first as Map;
      setState(
        () => _identity = CommunityIdentity(
          row?['name'] as String? ?? 'Membro',
          row?['avatar_url'] as String?,
          row?['founder'] == true,
        ),
      );
    } catch (_) {
      /* Keep the last safe identity while disconnected. */
    } finally {
      _loading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void didUpdateWidget(covariant CommunityIdentityBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _generation++;
      _identity = null;
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _client?.auth.currentUser;
    final own = user != null && user.id == widget.userId;
    final founder = own && AuthService.isProjectLeader(user);
    final metadata = user?.userMetadata;
    final identity = own
        ? CommunityIdentity(
            (metadata?['display_name'] as String?)?.trim().isNotEmpty == true
                ? (metadata!['display_name'] as String).trim()
                : founder
                ? 'Amaral'
                : 'Sua conta',
            metadata?['avatar_url'] as String?,
            founder,
          )
        : _identity ?? CommunityIdentity(widget.name, widget.avatarUrl, false);
    return widget.builder(context, identity);
  }
}
