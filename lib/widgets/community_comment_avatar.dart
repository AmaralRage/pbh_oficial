import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/public_member_profile_service.dart';
import '../models/public_member_profile.dart';

/// Resolve missing feed images through the same profile used by the profile page.
class ProfileCommentAvatar extends StatefulWidget {
  const ProfileCommentAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
  });
  final String userId;
  final String name;
  final String? avatarUrl;
  @override
  State<ProfileCommentAvatar> createState() => _ProfileCommentAvatarState();
}

class _ProfileCommentAvatarState extends State<ProfileCommentAvatar> {
  Future<PublicMemberProfile?>? _profile;
  void _resolve() {
    final client = Supabase.instance.client;
    _profile =
        client.auth.currentUser?.id != widget.userId &&
            (widget.avatarUrl?.trim().isEmpty ?? true)
        ? PublicMemberProfileService(client: client).fetch(widget.userId)
        : null;
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ProfileCommentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.avatarUrl != widget.avatarUrl) {
      _resolve();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, _) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.id == widget.userId) {
        return CommunityCommentAvatar(
          name: widget.name,
          avatarUrl: user!.userMetadata?['avatar_url'] as String?,
          founder: AuthService.isProjectLeader(user),
        );
      }
      return FutureBuilder<PublicMemberProfile?>(
        future: _profile,
        builder: (context, snapshot) => CommunityCommentAvatar(
          name: widget.name,
          avatarUrl: snapshot.data?.avatarUrl ?? widget.avatarUrl,
          founder: snapshot.data?.founder ?? false,
        ),
      );
    },
  );
}

/// A identidade vem do perfil, nunca de uma imagem escolhida pelo nome.
class CommunityCommentAvatar extends StatelessWidget {
  const CommunityCommentAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.founder = false,
  });
  final String name;
  final String? avatarUrl;
  final bool founder;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'M';
    return parts.length == 1
        ? parts.first[0].toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final placeholder = Center(
      child: Text(
        _initials,
        style: TextStyle(color: context.pbhColors.orange, fontSize: 12),
      ),
    );
    return CircleAvatar(
      backgroundColor: context.pbhColors.orangeDim,
      child: url == null || url.isEmpty
          ? founder
                ? ClipOval(
                    child: Image.asset(
                      'assets/images/perfil.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
                  )
                : placeholder
          : ClipOval(
              child: Image.network(
                url,
                key: ValueKey(url),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                gaplessPlayback: false,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}
