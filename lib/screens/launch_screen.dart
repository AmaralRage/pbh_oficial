import 'package:flutter/material.dart';

import '../core/config/supabase_config.dart';
import '../core/navigation/app_transitions.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/official_hero_background.dart';
import '../widgets/pbh_logo.dart';
import 'auth_gate.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key, this.onStart});

  final VoidCallback? onStart;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
  late final Animation<Offset> _rise = Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero)
      .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _start() {
    final onStart = widget.onStart;
    if (onStart != null) {
      onStart();
      return;
    }
    Navigator.of(context).pushReplacement(
      fadeSlideRoute(AuthGate(supabaseConfigured: SupabaseConfig.isConfigured)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: OfficialHeroBackground(
          imageAlignment: Alignment.center,
          darken: .1,
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
          child: SafeArea(
            child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(opacity: _fade, child: SlideTransition(position: _rise, child: const PbhLogo())),
                  const SizedBox(height: 18),
                  Container(width: 28, height: 2, color: AppColors.textSecondary),
                  const Spacer(flex: 2),
                  FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _rise,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppTextStyles.headline.copyWith(fontSize: 22, height: 1.15),
                          children: const [
                            TextSpan(text: 'Torne-se o homem\nque você '),
                            TextSpan(text: 'respeita', style: TextStyle(color: AppColors.orange)),
                            TextSpan(text: '\nno futuro.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(width: 44, height: 2, color: AppColors.orange),
                  const SizedBox(height: 22),
                  FadeTransition(
                    opacity: _fade,
                    child: Text('Disciplina hoje.\nLiberdade amanhã.', textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
                  ),
                  const Spacer(flex: 2),
                  FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _rise,
                      child: ElevatedButton(
                        onPressed: _start,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text('Começar agora'), SizedBox(width: 18), Icon(Icons.arrow_forward, size: 22)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    label: 'Apresentação inicial',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final active = index == 0;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: active ? 12 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: active ? AppColors.orange : AppColors.inactive,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
            ),
          ),
        ),
      );
}
