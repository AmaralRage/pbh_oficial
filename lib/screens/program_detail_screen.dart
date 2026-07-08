import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/program_model.dart';
import '../widgets/animated_entry.dart';
import '../widgets/official_hero_background.dart';

class ProgramDetailScreen extends StatefulWidget {
  final ProgramModel program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  bool _saved = false;
  late bool _started;

  @override
  void initState() {
    super.initState();
    _started = widget.program.progress > 0;
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;

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
              const SnackBar(content: Text('Link do programa pronto para compartilhar.')),
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
            AnimatedEntry(
              delayMs: 60,
              child: SizedBox(
                height: 390,
                child: OfficialHeroBackground(
                  imageAlignment: Alignment.bottomRight,
                  darken: 0,
                  padding: const EdgeInsets.fromLTRB(4, 22, 4, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROGRAMA', style: AppTextStyles.eyebrow),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 250,
                        child: Text(
                          program.title,
                          style: AppTextStyles.displayLarge.copyWith(fontSize: 31, height: 1.04),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 238,
                        child: Text(
                          program.tagline,
                          style: AppTextStyles.bodySmall.copyWith(height: 1.38),
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _InfoChip(icon: Icons.view_module_outlined, label: '${program.modules} Módulos'),
                          _InfoChip(icon: Icons.schedule_outlined, label: '${program.weeks} Semanas'),
                          _InfoChip(icon: Icons.star_border, label: program.levelLabel),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            AnimatedEntry(
              delayMs: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('O que você vai desenvolver', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      children: List.generate(program.outcomes.length, (index) {
                        final isLast = index == program.outcomes.length - 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.orange, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  program.outcomes[index],
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AnimatedEntry(
              delayMs: 210,
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _started = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Programa iniciado.')),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: Text(_started ? 'Continuar programa' : 'Iniciar programa'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _saved = !_saved),
                    icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border, size: 18),
                    label: Text(_saved ? 'Salvo para depois' : 'Salvar para depois'),
                  ),
                ],
              ),
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
          Text(label, style: AppTextStyles.chip.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
