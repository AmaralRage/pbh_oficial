import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _started = false;
  late final SharedPreferencesAsync _storage;
  String get _startedKey => 'pbh.program.${widget.program.id}.started';
  String get _savedKey => 'pbh.program.${widget.program.id}.saved';

  @override
  void initState() {
    super.initState();
    _storage = SharedPreferencesAsync();
    _loadProgramState();
  }

  Future<void> _loadProgramState() async {
    final values = await Future.wait([
      _storage.getBool(_startedKey),
      _storage.getBool(_savedKey),
    ]);
    if (!mounted) return;
    setState(() {
      _started = values[0] ?? false;
      _saved = values[1] ?? false;
    });
  }

  Future<void> _toggleSaved() async {
    final value = !_saved;
    setState(() => _saved = value);
    await _storage.setBool(_savedKey, value);
  }

  Future<void> _startProgram() async {
    await _storage.setBool(_startedKey, true);
    if (mounted) setState(() => _started = true);
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;

    return Scaffold(
      backgroundColor: context.pbhColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
            tooltip: _saved ? 'Remover dos salvos' : 'Salvar programa',
            onPressed: _toggleSaved,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Compartilhar programa',
            onPressed: () =>
                Share.share('${program.title}\n${program.tagline}'),
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
                      Text(
                        'PROGRAMA',
                        style: AppTextStyles.eyebrow.copyWith(
                          color: context.pbhColors.orangeLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 250,
                        child: Text(
                          program.title,
                          style: AppTextStyles.displayLarge.copyWith(
                            fontSize: 31,
                            height: 1.04,
                          ),
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
                          _InfoChip(
                            icon: Icons.view_module_outlined,
                            label: '${program.modules} Módulos',
                          ),
                          _InfoChip(
                            icon: Icons.schedule_outlined,
                            label: '${program.weeks} Semanas',
                          ),
                          _InfoChip(
                            icon: Icons.star_border,
                            label: program.levelLabel,
                          ),
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
                  Text(
                    'O que você vai desenvolver',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: context.pbhColors.surface.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.pbhColors.borderSubtle),
                    ),
                    child: Column(
                      children: List.generate(program.outcomes.length, (index) {
                        final isLast = index == program.outcomes.length - 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(
                                    bottom: BorderSide(
                                      color: context.pbhColors.borderSubtle,
                                    ),
                                  ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: context.pbhColors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  program.outcomes[index],
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: context.pbhColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: context.pbhColors.textTertiary,
                                size: 18,
                              ),
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
                    onPressed: _startProgram,
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: Text(
                      _started ? 'Continuar programa' : 'Iniciar programa',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _toggleSaved,
                    icon: Icon(
                      _saved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                    ),
                    label: Text(
                      _saved ? 'Salvo para depois' : 'Salvar para depois',
                    ),
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
        color: context.pbhColors.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.pbhColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.pbhColors.orange),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.chip.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
