import 'package:flutter/material.dart';
import '../widgets/challenge_celebration.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/challenge_model.dart';
import '../services/challenge_service.dart';
import '../widgets/official_hero_background.dart';

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({
    super.key,
    required this.challenge,
    required this.isAuthenticated,
    required this.onRequireLogin,
  });
  final ChallengeModel challenge;
  final bool isAuthenticated;
  final VoidCallback onRequireLogin;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final _service = ChallengeService();
  late ChallengeModel _challenge;
  bool _todayComplete = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    _load();
  }

  Future<void> _load() async {
    try {
      final challenges = await _service.fetchChallenges();
      final refreshed = challenges.firstWhere(
        (item) => item.id == widget.challenge.id,
      );
      final completed =
          widget.isAuthenticated &&
              refreshed.status != ChallengeStatus.notStarted
          ? await _service.completedToday(refreshed.id)
          : false;
      if (mounted)
        setState(() {
          _challenge = refreshed;
          _todayComplete = completed;
          _loading = false;
          _error = null;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.toString();
        });
    }
  }

  Future<void> _join() async {
    if (!widget.isAuthenticated) {
      widget.onRequireLogin();
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.join(_challenge.id);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Desafio iniciado. Seu progresso será salvo na sua conta.',
            ),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível iniciar: $error')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleToday() async {
    if (!widget.isAuthenticated) {
      widget.onRequireLogin();
      return;
    }
    final previous = _todayComplete;
    final wasCompleted = _challenge.status == ChallengeStatus.completed;
    setState(() {
      _todayComplete = !_todayComplete;
      _busy = true;
    });
    try {
      await _service.toggleToday(_challenge.id, previous);
      await _load();
      if (mounted &&
          _error == null &&
          !wasCompleted &&
          _challenge.status == ChallengeStatus.completed) {
        await ChallengeCelebration.show(context, _challenge);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _todayComplete = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar o progresso: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveChallenge() async {
    final focus = '${_challenge.title} ${_challenge.description}'.toLowerCase();
    final encouragement =
        focus.contains('trein') ||
            focus.contains('corrida') ||
            focus.contains('caminhada') ||
            focus.contains('corpo')
        ? 'Seu corpo se fortalece com constância, não com perfeição. Ajuste o ritmo e avance um treino de cada vez.'
        : focus.contains('leitura') ||
              focus.contains('estudo') ||
              focus.contains('idioma') ||
              focus.contains('escrita')
        ? 'Conhecimento se constrói página por página. Mesmo um passo pequeno mantém sua mente em movimento.'
        : focus.contains('celular') ||
              focus.contains('digital') ||
              focus.contains('redes') ||
              focus.contains('conteúdo')
        ? 'Recuperar o foco é um processo. Uma escolha consciente hoje já é um recomeço.'
        : focus.contains('sono') ||
              focus.contains('dormir') ||
              focus.contains('acordar')
        ? 'Uma rotina melhor começa com decisões possíveis, repetidas com paciência. Você pode ajustar e continuar.'
        : 'Uma fase difícil não define sua jornada. Reduza o ritmo se precisar e retome um passo de cada vez.';
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Antes de desistir'),
        content: Text(
          'Você já avançou ${_challenge.currentDay} de ${_challenge.totalDays} dias em "${_challenge.title}". '
          '$encouragement\n\n'
          'Se sair agora, os registros deste desafio serão apagados. Quer continuar mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuar o desafio'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desistir'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.leave(_challenge.id);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Desafio removido. Quando quiser, você poderá recomeçar.',
            ),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível sair do desafio: $error')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (_challenge.progress * 100).round();
    final joined = _challenge.status != ChallengeStatus.notStarted;
    final completed = _challenge.status == ChallengeStatus.completed;
    return Scaffold(
      backgroundColor: context.pbhColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Compartilhar desafio',
            onPressed: () => Share.share(
              'Estou participando do desafio ${_challenge.title} no PBH Oficial.',
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            SizedBox(
              height: 310,
              child: OfficialHeroBackground(
                imageAlignment: Alignment.bottomRight,
                darken: .08,
                padding: const EdgeInsets.fromLTRB(4, 22, 4, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.pbhColors.orangeDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DESAFIO',
                        style: AppTextStyles.eyebrow.copyWith(
                          color: context.pbhColors.orangeLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _challenge.title,
                      style: AppTextStyles.displayLarge.copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _challenge.description,
                      style: AppTextStyles.body.copyWith(fontSize: 15),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(
                          icon: Icons.flag_outlined,
                          label: '${_challenge.totalDays} dias',
                        ),
                        _InfoChip(
                          icon: Icons.star_border,
                          label: _challenge.levelLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Text(
                'Não foi possível carregar seu progresso. $_error',
                style: AppTextStyles.bodySmall,
              )
            else if (joined) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Seu progresso', style: AppTextStyles.titleMedium),
                  Text(
                    '$progressPercent%',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: context.pbhColors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: _challenge.progress,
                  minHeight: 8,
                  backgroundColor: context.pbhColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation(context.pbhColors.orange),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_challenge.currentDay} de ${_challenge.totalDays} dias registrados',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'O desafio pede um registro por dia cumprido. Os registros não precisam ser consecutivos; você pode retomar se perder um dia.',
                style: AppTextStyles.statLabel.copyWith(height: 1.4),
              ),
              const SizedBox(height: 22),
              if (!completed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.pbhColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.pbhColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _todayComplete
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: context.pbhColors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progresso de hoje',
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _todayComplete
                                  ? 'Dia registrado. Você manteve o compromisso.'
                                  : 'Concluiu a missão de hoje?',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _todayComplete,
                        onChanged: _busy ? null : (_) => _toggleToday(),
                      ),
                    ],
                  ),
                ),
              if (completed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.pbhColors.orangeDim,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: context.pbhColors.orange,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Desafio concluído. Parabéns pela consistência!',
                        ),
                      ),
                    ],
                  ),
                ),
              if (!completed) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _leaveChallenge,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Sair deste desafio'),
                  ),
                ),
              ],
            ] else ...[
              Text(
                'Comece quando estiver pronto. Seu progresso diário ficará salvo na sua conta.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _busy ? null : _join,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _busy
                      ? 'Iniciando...'
                      : widget.isAuthenticated
                      ? 'Iniciar desafio'
                      : 'Entre para iniciar',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: context.pbhColors.surface.withOpacity(.88),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.pbhColors.borderSubtle),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.pbhColors.orange),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.chip),
      ],
    ),
  );
}
