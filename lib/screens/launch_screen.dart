import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/navigation/app_transitions.dart';
import '../main_navigation.dart';
import '../widgets/official_hero_background.dart';
import '../widgets/pbh_logo.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  int _page = 0;

  void _start() {
    Navigator.of(context).pushReplacement(
      fadeSlideRoute(const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OfficialHeroBackground(
        imageAlignment: Alignment.center,
        darken: 0.1,
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 34),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              const PbhLogo(),
              const SizedBox(height: 18),
              Container(width: 28, height: 2, color: AppColors.textSecondary),
              const Spacer(flex: 2),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 22,
                    height: 1.15,
                  ),
                  children: const [
                    TextSpan(text: 'Torne-se o homem\nque você '),
                    TextSpan(
                      text: 'respeita',
                      style: TextStyle(color: AppColors.orange),
                    ),
                    TextSpan(text: '\nno futuro.'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(width: 44, height: 2, color: AppColors.orange),
              const SizedBox(height: 22),
              Text(
                'Disciplina hoje.\nLiberdade amanhã.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
              const Spacer(flex: 2),
              ElevatedButton(
                onPressed: _start,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Começar agora'),
                    SizedBox(width: 18),
                    Icon(Icons.arrow_forward, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final active = index == _page;
                  return GestureDetector(
                    onTap: () => setState(() => _page = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: active ? 12 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? AppColors.orange : AppColors.inactive,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
