import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge_model.dart';
import 'auth_service.dart';

const _expandedChallengeCatalog = <Map<String, dynamic>>[
  {
    'id': '7day_focus',
    'title': 'Foco por 7 dias',
    'description':
        'Uma semana para reduzir distrações e cumprir suas prioridades.',
    'total_days': 7,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
  {
    'id': 'phone_free_morning',
    'title': 'Manhã sem celular',
    'description': 'Comece o dia longe das notificações e com intenção.',
    'total_days': 7,
    'level': 'iniciante',
    'icon_key': 'phone',
  },
  {
    'id': 'walk_daily',
    'title': 'Caminhada diária',
    'description': 'Inclua movimento leve todos os dias.',
    'total_days': 14,
    'level': 'iniciante',
    'icon_key': 'fitness',
  },
  {
    'id': 'water_habit',
    'title': 'Hidratação consciente',
    'description': 'Crie uma rotina consistente de hidratação.',
    'total_days': 14,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
  {
    'id': 'gratitude_journal',
    'title': 'Diário de gratidão',
    'description': 'Registre diariamente algo pelo qual você é grato.',
    'total_days': 14,
    'level': 'iniciante',
    'icon_key': 'book',
  },
  {
    'id': 'bedtime_routine',
    'title': 'Rotina de sono',
    'description': 'Prepare corpo e mente para dormir no mesmo horário.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'sunrise',
  },
  {
    'id': '20min_reading',
    'title': '20 minutos de leitura',
    'description': 'Leia um pouco todos os dias e avance com constância.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'book',
  },
  {
    'id': 'no_sugar_week',
    'title': 'Uma semana sem açúcar',
    'description': 'Observe seus hábitos e reduza o açúcar adicionado.',
    'total_days': 7,
    'level': 'intermediario',
    'icon_key': 'fitness',
  },
  {
    'id': 'cold_shower',
    'title': 'Banho consciente',
    'description': 'Finalize o banho com alguns instantes de água fria.',
    'total_days': 14,
    'level': 'intermediario',
    'icon_key': 'flag',
  },
  {
    'id': 'early_riser',
    'title': 'Acordar cedo',
    'description': 'Levante no horário planejado e proteja sua manhã.',
    'total_days': 21,
    'level': 'intermediario',
    'icon_key': 'sunrise',
  },
  {
    'id': 'daily_meditation',
    'title': 'Meditação diária',
    'description': 'Reserve alguns minutos para respirar e recuperar o foco.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
  {
    'id': 'tidy_space',
    'title': 'Ambiente em ordem',
    'description': 'Dedique alguns minutos por dia para organizar seu espaço.',
    'total_days': 14,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
  {
    'id': 'no_social_morning',
    'title': 'Manhã sem redes sociais',
    'description': 'Adie as redes sociais e comece o dia com propósito.',
    'total_days': 14,
    'level': 'intermediario',
    'icon_key': 'phone',
  },
  {
    'id': 'pushup_progress',
    'title': 'Progressão de flexões',
    'description': 'Treine flexões com técnica e progressão gradual.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'fitness',
  },
  {
    'id': 'run_beginner',
    'title': 'Corrida para iniciantes',
    'description': 'Construa resistência com sessões progressivas.',
    'total_days': 30,
    'level': 'iniciante',
    'icon_key': 'fitness',
  },
  {
    'id': 'core_strength',
    'title': 'Força do core',
    'description': 'Pratique exercícios para estabilidade e força central.',
    'total_days': 21,
    'level': 'intermediario',
    'icon_key': 'fitness',
  },
  {
    'id': 'mobility_daily',
    'title': 'Mobilidade diária',
    'description': 'Cuide da mobilidade com uma rotina breve.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'fitness',
  },
  {
    'id': 'no_alcohol',
    'title': 'Pausa no álcool',
    'description': 'Experimente um período sem bebidas alcoólicas.',
    'total_days': 30,
    'level': 'avancado',
    'icon_key': 'flag',
  },
  {
    'id': 'budget_month',
    'title': 'Mês de orçamento',
    'description': 'Registre gastos e acompanhe seu orçamento diariamente.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'book',
  },
  {
    'id': 'learn_language',
    'title': 'Estudo de idioma',
    'description': 'Pratique um novo idioma todos os dias.',
    'total_days': 30,
    'level': 'iniciante',
    'icon_key': 'book',
  },
  {
    'id': 'write_daily',
    'title': 'Escrita diária',
    'description':
        'Escreva algumas linhas para organizar pensamentos e ideias.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'book',
  },
  {
    'id': 'one_task',
    'title': 'Uma prioridade por dia',
    'description':
        'Conclua uma tarefa importante antes de dispersar sua atenção.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'flag',
  },
  {
    'id': 'no_complaints',
    'title': 'Sem reclamações',
    'description':
        'Troque reclamações por ações construtivas durante a jornada.',
    'total_days': 14,
    'level': 'intermediario',
    'icon_key': 'flag',
  },
  {
    'id': 'kindness_daily',
    'title': 'Gentileza intencional',
    'description': 'Faça uma ação gentil e consciente por dia.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
  {
    'id': 'call_family',
    'title': 'Presença com a família',
    'description': 'Separe tempo diário para se conectar com quem importa.',
    'total_days': 14,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
  {
    'id': 'cook_at_home',
    'title': 'Cozinhar em casa',
    'description': 'Prepare refeições em casa com planejamento simples.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'fitness',
  },
  {
    'id': 'protein_breakfast',
    'title': 'Café da manhã nutritivo',
    'description': 'Construa uma rotina matinal com escolhas nutritivas.',
    'total_days': 14,
    'level': 'iniciante',
    'icon_key': 'fitness',
  },
  {
    'id': 'stretch_breaks',
    'title': 'Pausas para alongar',
    'description': 'Faça pausas curtas para alongamento durante o dia.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'fitness',
  },
  {
    'id': 'weekly_planning',
    'title': 'Planejamento semanal',
    'description': 'Planeje prioridades e revise seu progresso por semana.',
    'total_days': 28,
    'level': 'intermediario',
    'icon_key': 'book',
  },
  {
    'id': 'focus_blocks',
    'title': 'Blocos de foco',
    'description': 'Trabalhe em períodos concentrados com pausas planejadas.',
    'total_days': 21,
    'level': 'intermediario',
    'icon_key': 'flag',
  },
  {
    'id': 'no_impulse_buy',
    'title': 'Compras conscientes',
    'description': 'Evite compras por impulso e registre suas escolhas.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'book',
  },
  {
    'id': 'donate_weekly',
    'title': 'Generosidade semanal',
    'description': 'Pratique uma ação de generosidade a cada semana.',
    'total_days': 28,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
  {
    'id': 'service_month',
    'title': 'Mês de serviço',
    'description': 'Contribua com sua comunidade de forma consistente.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'flag',
  },
  {
    'id': 'lead_by_example',
    'title': 'Liderar pelo exemplo',
    'description': 'Pratique diariamente os valores que deseja inspirar.',
    'total_days': 30,
    'level': 'avancado',
    'icon_key': 'flag',
  },
  {
    'id': 'public_speaking',
    'title': 'Prática de comunicação',
    'description': 'Desenvolva confiança ao se expressar com clareza.',
    'total_days': 21,
    'level': 'intermediario',
    'icon_key': 'book',
  },
  {
    'id': 'conflict_reflection',
    'title': 'Reflexão após conflitos',
    'description': 'Reserve um momento para aprender com conversas difíceis.',
    'total_days': 14,
    'level': 'intermediario',
    'icon_key': 'book',
  },
  {
    'id': 'digital_sunset',
    'title': 'Pôr do sol digital',
    'description': 'Desconecte-se das telas antes do horário de dormir.',
    'total_days': 21,
    'level': 'intermediario',
    'icon_key': 'phone',
  },
  {
    'id': 'weekend_outdoors',
    'title': 'Fim de semana ao ar livre',
    'description': 'Passe tempo ao ar livre e recarregue sua energia.',
    'total_days': 28,
    'level': 'iniciante',
    'icon_key': 'fitness',
  },
  {
    'id': 'cycling_month',
    'title': 'Ciclismo constante',
    'description': 'Pedale com regularidade e aumente o percurso gradualmente.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'fitness',
  },
  {
    'id': 'swimming_routine',
    'title': 'Natação consistente',
    'description': 'Construa uma rotina de natação com progressão segura.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'fitness',
  },
  {
    'id': 'bodyweight_month',
    'title': 'Treino com peso corporal',
    'description': 'Mantenha uma rotina progressiva usando o peso do corpo.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'fitness',
  },
  {
    'id': 'no_takeout',
    'title': 'Cozinha planejada',
    'description': 'Planeje refeições e reduza pedidos por conveniência.',
    'total_days': 21,
    'level': 'intermediario',
    'icon_key': 'fitness',
  },
  {
    'id': 'content_fast',
    'title': 'Pausa de conteúdo',
    'description': 'Reduza o consumo passivo de conteúdo digital.',
    'total_days': 14,
    'level': 'intermediario',
    'icon_key': 'phone',
  },
  {
    'id': 'morning_pages',
    'title': 'Páginas matinais',
    'description': 'Escreva pela manhã para clarear ideias e intenções.',
    'total_days': 30,
    'level': 'iniciante',
    'icon_key': 'book',
  },
  {
    'id': 'purpose_review',
    'title': 'Revisão de propósito',
    'description': 'Reflita diariamente sobre valores e direção de vida.',
    'total_days': 21,
    'level': 'intermediario',
    'icon_key': 'book',
  },
  {
    'id': 'financial_learning',
    'title': 'Educação financeira',
    'description': 'Estude finanças pessoais um pouco todos os dias.',
    'total_days': 30,
    'level': 'iniciante',
    'icon_key': 'book',
  },
  {
    'id': 'gratitude_letters',
    'title': 'Cartas de agradecimento',
    'description': 'Expresse gratidão por escrito a pessoas importantes.',
    'total_days': 14,
    'level': 'iniciante',
    'icon_key': 'book',
  },
  {
    'id': 'consistent_prayer',
    'title': 'Momento de oração',
    'description':
        'Reserve um momento diário para oração ou reflexão espiritual.',
    'total_days': 30,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
  {
    'id': 'volunteer_month',
    'title': 'Voluntariado consistente',
    'description': 'Dedique tempo para servir e apoiar outras pessoas.',
    'total_days': 30,
    'level': 'intermediario',
    'icon_key': 'flag',
  },
  {
    'id': 'creative_practice',
    'title': 'Prática criativa',
    'description': 'Dedique alguns minutos diários a uma habilidade criativa.',
    'total_days': 30,
    'level': 'iniciante',
    'icon_key': 'book',
  },
  {
    'id': 'no_snooze',
    'title': 'Levantar sem soneca',
    'description': 'Levante no horário escolhido sem adiar o despertador.',
    'total_days': 21,
    'level': 'intermediario',
    'icon_key': 'sunrise',
  },
  {
    'id': 'five_minute_rule',
    'title': 'Regra dos cinco minutos',
    'description':
        'Comece tarefas importantes com cinco minutos de ação focada.',
    'total_days': 21,
    'level': 'iniciante',
    'icon_key': 'flag',
  },
];

class ChallengeService {
  ChallengeService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<List<ChallengeModel>> fetchChallenges() async {
    final catalog = <Map<String, dynamic>>[];
    try {
      final rows = await _client
          .from('challenge_catalog')
          .select()
          .order('title');
      catalog.addAll(rows.map((row) => Map<String, dynamic>.from(row)));
    } catch (_) {
      // Mantém o catálogo visível enquanto a migration remota é aplicada.
    }
    for (final item in _expandedChallengeCatalog) {
      if (!catalog.any((row) => row['id'] == item['id'])) catalog.add(item);
    }
    catalog.sort(
      (a, b) => (a['title'] as String).compareTo(b['title'] as String),
    );
    final userId = _userId;
    final leaderCompleted = AuthService.isProjectLeader(
      _client.auth.currentUser,
    );
    final joined = <String>{};
    final counts = <String, int>{};
    final achieved = <String, DateTime>{};
    if (userId != null && !leaderCompleted) {
      final joinedRows = await _client
          .from('user_challenges')
          .select('challenge_id')
          .eq('user_id', userId);
      joined.addAll(joinedRows.map((row) => row['challenge_id'] as String));
      counts.addAll(await completionCounts());
      try {
        final dates =
            await _client.rpc('my_challenge_achievement_dates') as List;
        if (_userId != userId) throw StateError('A conta mudou.');
        for (final date in dates) {
          final parsed = DateTime.tryParse(
            date['completed_on'] as String? ?? '',
          );
          if (parsed != null) achieved[date['challenge_id'] as String] = parsed;
        }
      } catch (_) {
        if (_userId != userId) rethrow;
        // Dates are optional for older databases; never invent a date.
      }
    }
    return catalog.map((row) {
      final id = row['id'] as String;
      final days = row['total_days'] as int;
      final count = leaderCompleted ? days : counts[id] ?? 0;
      final status = leaderCompleted
          ? ChallengeStatus.completed
          : !joined.contains(id)
          ? ChallengeStatus.notStarted
          : count >= days
          ? ChallengeStatus.completed
          : ChallengeStatus.active;
      final level = switch (row['level'] as String) {
        'iniciante' => ChallengeLevel.iniciante,
        'avancado' => ChallengeLevel.avancado,
        _ => ChallengeLevel.intermediario,
      };
      return ChallengeModel(
        id: id,
        title: row['title'] as String,
        description: row['description'] as String,
        totalDays: days,
        currentDay: count,
        achievedOn: achieved[id],
        level: level,
        status: status,
        icon: _iconFor(row['icon_key'] as String),
      );
    }).toList();
  }

  Future<void> join(String challengeId) async {
    final userId = _userId;
    if (userId == null)
      throw StateError('Entre na sua conta para iniciar o desafio.');
    await _client.from('user_challenges').insert({
      'user_id': userId,
      'challenge_id': challengeId,
    });
  }

  Future<Map<String, int>> completionCounts() async {
    final user = _userId;
    if (user == null) return {};
    try {
      final rows = await _client.rpc('my_challenge_completion_counts') as List;
      return {
        for (final row in rows)
          row['challenge_id'] as String: (row['completed_days'] as num).toInt(),
      };
    } on PostgrestException catch (error) {
      if (!['PGRST202', '42883'].contains(error.code)) rethrow;
      // Compatibility with databases where the new RPC has not been deployed yet.
      final counts = <String, int>{};
      const size = 500;
      for (var offset = 0; ; offset += size) {
        final rows = await _client
            .from('challenge_day_completions')
            .select('challenge_id')
            .eq('user_id', user)
            .order('challenge_id')
            .order('completed_on')
            .range(offset, offset + size - 1);
        for (final row in rows) {
          final id = row['challenge_id'] as String;
          counts[id] = (counts[id] ?? 0) + 1;
        }
        if (rows.length < size) return counts;
      }
    }
  }

  Future<void> leave(String challengeId) async {
    final userId = _userId;
    if (userId == null)
      throw StateError('Entre na sua conta para sair do desafio.');
    // Deleting the enrollment also removes its daily records through the
    // database foreign key, so a future attempt starts cleanly.
    await _client
        .from('user_challenges')
        .delete()
        .eq('user_id', userId)
        .eq('challenge_id', challengeId);
  }

  Future<bool> completedToday(String challengeId) async {
    final userId = _userId;
    if (userId == null) return false;
    final today = _dateKey(DateTime.now());
    final row = await _client
        .from('challenge_day_completions')
        .select('completed_on')
        .eq('user_id', userId)
        .eq('challenge_id', challengeId)
        .eq('completed_on', today)
        .maybeSingle();
    return row != null;
  }

  Future<void> toggleToday(String challengeId, bool completed) async {
    final userId = _userId;
    if (userId == null)
      throw StateError('Entre na sua conta para registrar seu progresso.');
    final today = _dateKey(DateTime.now());
    if (completed) {
      await _client
          .from('challenge_day_completions')
          .delete()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .eq('completed_on', today);
    } else {
      await _client.from('challenge_day_completions').insert({
        'user_id': userId,
        'challenge_id': challengeId,
        'completed_on': today,
      });
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  IconData _iconFor(String key) => switch (key) {
    'sunrise' => Icons.wb_twilight_outlined,
    'phone' => Icons.smartphone_outlined,
    'fitness' => Icons.fitness_center_outlined,
    'book' => Icons.menu_book_outlined,
    _ => Icons.flag_outlined,
  };
}
