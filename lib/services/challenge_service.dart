import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge_model.dart';

class ChallengeService {
  ChallengeService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<List<ChallengeModel>> fetchChallenges() async {
    final catalog = await _client.from('challenge_catalog').select().order('title');
    final userId = _userId;
    final joined = <String>{};
    final counts = <String, int>{};
    if (userId != null) {
      final joinedRows = await _client.from('user_challenges').select('challenge_id').eq('user_id', userId);
      joined.addAll(joinedRows.map((row) => row['challenge_id'] as String));
      final completionRows = await _client.from('challenge_day_completions').select('challenge_id').eq('user_id', userId);
      for (final row in completionRows) {
        final id = row['challenge_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return catalog.map((row) {
      final id = row['id'] as String;
      final days = row['total_days'] as int;
      final count = counts[id] ?? 0;
      final status = !joined.contains(id)
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
        level: level,
        status: status,
        icon: _iconFor(row['icon_key'] as String),
      );
    }).toList();
  }

  Future<void> join(String challengeId) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para iniciar o desafio.');
    await _client.from('user_challenges').insert({'user_id': userId, 'challenge_id': challengeId});
  }

  Future<bool> completedToday(String challengeId) async {
    final userId = _userId;
    if (userId == null) return false;
    final today = _dateKey(DateTime.now());
    final row = await _client.from('challenge_day_completions').select('completed_on').eq('user_id', userId).eq('challenge_id', challengeId).eq('completed_on', today).maybeSingle();
    return row != null;
  }

  Future<void> toggleToday(String challengeId, bool completed) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para registrar seu progresso.');
    final today = _dateKey(DateTime.now());
    if (completed) {
      await _client.from('challenge_day_completions').delete().eq('user_id', userId).eq('challenge_id', challengeId).eq('completed_on', today);
    } else {
      await _client.from('challenge_day_completions').insert({'user_id': userId, 'challenge_id': challengeId, 'completed_on': today});
    }
  }

  String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  IconData _iconFor(String key) => switch (key) {
        'sunrise' => Icons.wb_twilight_outlined,
        'phone' => Icons.smartphone_outlined,
        'fitness' => Icons.fitness_center_outlined,
        'book' => Icons.menu_book_outlined,
        _ => Icons.flag_outlined,
      };
}
