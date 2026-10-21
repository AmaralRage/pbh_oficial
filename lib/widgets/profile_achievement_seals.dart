import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/profile_achievement.dart';
import '../services/profile_achievement_service.dart';
import 'supreme_seal_art.dart';
import 'deferred_seal_art.dart';

final _stillSeals = <String, Future<ui.Image>>{};
Future<ui.Image> _firstFrame(String asset) =>
    _stillSeals.putIfAbsent(asset, () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    });

class ProfileAchievementSeals extends StatelessWidget {
  const ProfileAchievementSeals({super.key, required this.achievements});
  final List<ProfileAchievement> achievements;

  static void showDetails(BuildContext context, ProfileAchievement badge) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar conquista',
      barrierColor: Colors.black87,
      transitionDuration: Duration(milliseconds: reduced ? 0 : 380),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: .78, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
      pageBuilder: (context, _, __) => Dialog(
        backgroundColor: Color.lerp(AppColors.background, badge.color, .04),
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: badge.color.withValues(alpha: .65)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Fechar conquista',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Text(
                  'SELO CONQUISTADO',
                  style: AppTextStyles.eyebrow.copyWith(color: badge.color),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) => badge.artAsset != null
                      ? DeferredSealArt(
                          preview: Image.asset(
                            badge.artAsset!,
                            width: math.min(constraints.maxWidth, 300),
                            height: math.min(constraints.maxWidth, 300),
                            fit: BoxFit.contain,
                          ),
                          builder: () => SupremeSealArt(
                            achievement: badge,
                            size: math.min(constraints.maxWidth, 300),
                          ),
                        )
                      : _AnimatedSeal(
                          badge: badge,
                          size: math.min(constraints.maxWidth, 300),
                          expanded: true,
                        ),
                ),
                const SizedBox(height: 28),
                Text(
                  badge.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headline.copyWith(color: badge.color),
                ),
                const SizedBox(height: 12),
                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(height: 1.6),
                ),
                if (badge.artAsset != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    badge.artCaption ??
                        (badge.id == 'platinum'
                            ? 'COLEÇÃO COMPLETA • PLATINA PBH'
                            : '${badge.category} • TROFÉU SUPREMO'),
                    style: AppTextStyles.eyebrow.copyWith(
                      color: badge.color,
                      fontSize: 10,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar ao perfil'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: AppColors.orange,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text('Sua história começa aqui', style: AppTextStyles.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Complete desafios e mantenha sua rotina para conquistar os selos que vão brilhar no seu perfil.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }
    return TickerMode(
      enabled: ModalRoute.isCurrentOf(context) ?? true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 340 ? 2 : 3;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: achievements.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              mainAxisExtent: 170,
            ),
            itemBuilder: (context, index) {
              final badge = achievements[index];
              return Semantics(
                button: true,
                label: '${badge.title}, conquistado. Ver detalhes',
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => showDetails(context, badge),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: badge.color.withValues(alpha: .3),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            badge.color.withValues(alpha: .09),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                        child: Column(
                          children: [
                            _AnimatedSeal(badge: badge, size: 88),
                            const SizedBox(height: 12),
                            Text(
                              badge.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.statLabel.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AnimatedSeal extends StatefulWidget {
  const _AnimatedSeal({
    required this.badge,
    required this.size,
    this.expanded = false,
  });
  final ProfileAchievement badge;
  final double size;
  final bool expanded;
  @override
  State<_AnimatedSeal> createState() => _AnimatedSealState();
}

class _AnimatedSealState extends State<_AnimatedSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _motion,
        child: badge.artAsset == null
            ? null
            : RepaintBoundary(
                child: ClipOval(
                  child: reduced
                      ? FutureBuilder<ui.Image>(
                          future: _firstFrame(badge.artAsset!),
                          builder: (context, snapshot) => snapshot.hasData
                              ? RawImage(
                                  image: snapshot.data,
                                  fit: BoxFit.contain,
                                )
                              : Icon(
                                  badge.icon,
                                  color: badge.color,
                                  size: widget.size * .45,
                                ),
                        )
                      : Image.asset(
                          badge.artAsset!,
                          fit: BoxFit.contain,
                          cacheWidth:
                              (widget.size *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .ceil(),
                          excludeFromSemantics: true,
                        ),
                ),
              ),
        builder: (context, artwork) {
          final wave = math.sin(_motion.value * math.pi * 2);
          return Transform.translate(
            offset: Offset(0, reduced ? 0 : wave * (widget.expanded ? 5 : 3)),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: badge.color.withValues(
                      alpha: .12 + (wave + 1) * .04,
                    ),
                    blurRadius: widget.expanded ? 38 : 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: badge.artAsset != null
                  ? artwork
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          margin: EdgeInsets.all(widget.size * .07),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                badge.color.withValues(alpha: .19),
                                const Color(0xFF15100D),
                              ],
                            ),
                            border: Border.all(
                              color: badge.color.withValues(alpha: .8),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Transform.rotate(
                          angle: reduced ? 0 : _motion.value * math.pi * 2,
                          child: CustomPaint(
                            size: Size.square(widget.size),
                            painter: _SealOrbit(badge.color),
                          ),
                        ),
                        Icon(
                          badge.icon,
                          color: badge.color,
                          size: widget.size * .43,
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _SealOrbit extends CustomPainter {
  const _SealOrbit(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..color = color.withValues(alpha: .65);
    for (var i = 0; i < 18; i++) {
      final angle = i * math.pi * 2 / 18;
      final offset =
          Offset(math.cos(angle), math.sin(angle)) * size.width * .47;
      canvas.drawCircle(center + offset, i % 3 == 0 ? 1.8 : .9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SealOrbit oldDelegate) =>
      oldDelegate.color != color;
}

class GrantProfileSealDialog extends StatefulWidget {
  const GrantProfileSealDialog({super.key});
  @override
  State<GrantProfileSealDialog> createState() => _GrantProfileSealDialogState();
}

class _GrantProfileSealDialogState extends State<GrantProfileSealDialog> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  ProfileAchievement _selectedSeal = ProfileAchievement.supremeSeals.first;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ProfileAchievementService().grantSupremeSeal(
        _email.text,
        _selectedSeal.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selo ${_selectedSeal.title} concedido à conta informada.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            error is PostgrestException &&
                (error.code == '22023' || error.code == '42501')
            ? error.message
            : 'Não foi possível conceder o selo. Confira se as concessões já foram habilitadas no servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Conceder selo supremo'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<ProfileAchievement>(
                initialValue: _selectedSeal,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Selo'),
                items: ProfileAchievement.supremeSeals
                    .map(
                      (seal) => DropdownMenuItem(
                        value: seal,
                        child: Text(
                          '${seal.title} • ${seal.category}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (seal) {
                        if (seal != null) setState(() => _selectedSeal = seal);
                      },
              ),
              const SizedBox(height: 10),
              const Text(
                'Informe o e-mail confirmado da pessoa que receberá esta conquista no perfil.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(labelText: 'E-mail da conta'),
                validator: (value) =>
                    RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Informe um e-mail válido.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.orange)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _grant,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Conceder selo'),
        ),
      ],
    ),
  );
}
