import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/pbh_palette.dart';
import '../models/profile_style.dart';
import '../services/auth_service.dart';

class ProfileThemeScope extends StatelessWidget {
  const ProfileThemeScope({
    super.key,
    required this.builder,
    this.themeId,
    this.founder = false,
  });
  final WidgetBuilder builder;
  final String? themeId;
  final bool founder;
  @override
  Widget build(BuildContext context) {
    final user = themeId == null
        ? Supabase.instance.client.auth.currentUser
        : null;
    final isFounder = themeId == null
        ? AuthService.isProjectLeader(user)
        : founder;
    final id =
        themeId ??
        ProfileStyle.fromMetadata(
          user?.userMetadata ?? {},
          founder: isFounder,
        ).profileTheme;
    final palette = id == 'app'
        ? context.pbhColors
        : PbhPalette.resolve(id, founder: isFounder);
    return Theme(
      data: AppTheme.forPalette(palette),
      child: Builder(
        builder: (context) => ColoredBox(
          color: context.pbhColors.background,
          child: builder(context),
        ),
      ),
    );
  }
}
