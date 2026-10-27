import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/challenge_model.dart';

class ChallengeCelebration extends StatelessWidget {
  const ChallengeCelebration({super.key, required this.challenge});
  final ChallengeModel challenge;
  static Future<void> show(BuildContext context, ChallengeModel challenge) =>
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fechar conquista',
        transitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 300,
        ),
        transitionBuilder: (context, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: .85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
        pageBuilder: (_, _, _) => ChallengeCelebration(challenge: challenge),
      );
  String get tier => challenge.totalDays <= 7
      ? 'Bronze'
      : challenge.totalDays <= 14
      ? 'Prata'
      : 'Ouro';
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final artwork = challenge.totalDays <= 7
        ? 'bronze'
        : challenge.totalDays <= 14
        ? 'prata'
        : 'ouro';
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Você conquistou!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: reduced ? 0 : 1600),
                  builder: (context, t, child) => CustomPaint(
                    foregroundPainter: reduced ? null : _CelebrationPainter(t),
                    child: child,
                  ),
                  child: Image.asset(
                    'assets/images/trofeu_${artwork}_pbh.png',
                    width: 180,
                    height: 180,
                    cacheWidth: 540,
                    semanticLabel: 'Troféu de $tier',
                  ),
                ),
                Text(
                  challenge.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$tier · ${challenge.totalDays} dias de compromisso cumprido.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (buttonContext) => OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartilhar conquista'),
                    onPressed: () async {
                      final box =
                          buttonContext.findRenderObject() as RenderBox?;
                      try {
                        await Share.share(
                          'Conquistei o troféu de $tier no desafio "${challenge.title}" do PBH Oficial! ${challenge.totalDays} dias de compromisso cumprido.',
                          sharePositionOrigin: box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        );
                      } catch (_) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Não foi possível abrir o compartilhamento.',
                              ),
                            ),
                          );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continuar minha jornada'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    const colors = [
      Color(0xFFFFC45A),
      Color(0xFFFF6B26),
      Color(0xFFBB92FF),
      Color(0xFF80DDD5),
    ];
    for (var i = 0; i < 28; i++) {
      final angle = i * 2.39996;
      final distance = (30 + (i % 5) * 12) * progress;
      final point =
          size.center(Offset.zero) +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance + progress * progress * 30,
          );
      canvas.drawCircle(
        point,
        2 * (1 - progress),
        Paint()..color = colors[i % 4].withValues(alpha: 1 - progress),
      );
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
