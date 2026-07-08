import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
import '../widgets/official_hero_background.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final ChallengeModel challenge;

  const ChallengeDetailScreen({super.key, required this.challenge});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  late bool _joined;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _joined = widget.challenge.status == ChallengeStatus.active;
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final progressPercent = (challenge.progress * 100).round();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => setState(() => _saved = !_saved),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link do desafio pronto para compartilhar.')),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            SizedBox(
              height: 330,
              child: OfficialHeroBackground(
                imageAlignment: Alignment.bottomRight,
                darken: 0.08,
                padding: const EdgeInsets.fromLTRB(4, 22, 4, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.orangeDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('DESAFIO', style: AppTextStyles.eyebrow),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      challenge.title,
                      style: AppTextStyles.displayLarge.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      challenge.description,
                      style: AppTextStyles.body.copyWith(fontSize: 15),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(icon: Icons.flag_outlined, label: '${challenge.totalDays} dias'),
                        _InfoChip(icon: Icons.star_border, label: challenge.levelLabel),
                        _InfoChip(
                          icon: Icons.groups_outlined,
                          label: '${challenge.participants} homens',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (challenge.status == ChallengeStatus.active) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progresso atual', style: AppTextStyles.titleMedium),
                  Text('$progressPercent%', style: AppTextStyles.titleMedium.copyWith(color: AppColors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: challenge.progress,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: const AlwaysStoppedAnimation(AppColors.orange),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text('Missões do desafio', style: AppTextStyles.titleMedium),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Column(
                children: [
                  _MissionRow(label: 'Cumprir a rotina diária'),
                  _MissionRow(label: 'Registrar evolução no fim do dia'),
                  _MissionRow(label: 'Manter foco físico e mental'),
                  _MissionRow(label: 'Compartilhar uma vitória semanal', isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                final wasJoined = _joined;
                setState(() => _joined = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(wasJoined ? 'Desafio já está ativo.' : 'Desafio iniciado.')),
                );
              },
              icon: Icon(_joined ? Icons.check_circle : Icons.play_arrow, size: 20),
              label: Text(_joined ? 'Desafio em andamento' : 'Iniciar desafio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.orange),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.chip),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final String label;
  final bool isLast;

  const _MissionRow({required this.label, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.orange, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary))),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
        ],
      ),
    );
  }
}
