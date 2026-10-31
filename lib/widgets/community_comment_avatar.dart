import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'community_identity.dart';

class ProfileCommentAvatar extends StatelessWidget {
  const ProfileCommentAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
  });
  final String userId, name;
  final String? avatarUrl;
  @override
  Widget build(BuildContext context) => CommunityIdentityBuilder(
    userId: userId,
    name: name,
    avatarUrl: avatarUrl,
    builder: (context, identity) => CommunityCommentAvatar(
      name: identity.name,
      avatarUrl: identity.avatarUrl,
      founder: identity.founder,
    ),
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
