import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/weekly_review.dart';
import 'habit_service.dart';
import 'program_service.dart';

class WeeklyReviewService {
  WeeklyReviewService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  Future<WeeklyReview> load(
    Iterable<ProgramProgress>? progress, {
    DateTime? now,
  }) async {
    final account = _client.auth.currentUser?.id;
    final today = now ?? DateTime.now();
    final start = WeeklyReview.monday(today);
    final previous = DateTime(start.year, start.month, start.day - 7);
    final previousEnd = DateTime(today.year, today.month, today.day - 7);
    int? habits, previousHabits, challengeDays, previousChallengeDays;
    final service = HabitService(client: _client);
    try {
      final selected = await service.selectedHabitKeys();
      final weeks = await Future.wait([
        service.weekCounts(today, selectedHabits: selected),
        service.weekCounts(previous, selectedHabits: selected),
      ]);
      habits = weeks[0].take(today.weekday).fold<int>(0, (a, b) => a + b);
      previousHabits = weeks[1].take(today.weekday).fold<int>(0, (a, b) => a + b);
    } catch (_) {
      /* Cada fonte fica indisponível separadamente. */
    }
    if (account == null) {
      challengeDays = 0;
      previousChallengeDays = 0;
    } else {
      try {
        final dates = <String>[];
        for (var offset = 0; ; offset += 1000) {
          final rows = await _client
              .from('challenge_day_completions')
              .select('completed_on,challenge_id')
              .eq('user_id', account)
              .gte('completed_on', WeeklyReview.dayKey(previous))
              .lte('completed_on', WeeklyReview.dayKey(today))
              .order('completed_on')
              .order('challenge_id')
              .range(offset, offset + 999)
              .timeout(const Duration(seconds: 8));
          dates.addAll(rows.map((r) => r['completed_on'] as String));
          if (rows.length < 1000) break;
        }
        challengeDays = dates
            .where((d) => d.compareTo(WeeklyReview.dayKey(start)) >= 0)
            .length;
        previousChallengeDays = dates
            .where((d) => d.compareTo(WeeklyReview.dayKey(previousEnd)) <= 0)
            .length;
      } catch (_) {
        /* Não transformar falha de rede em progresso zero. */
      }
    }
    if (account != _client.auth.currentUser?.id) {
      throw StateError('A conta mudou. Atualize a tela.');
    }
    return WeeklyReview(
      start: start,
      today: today,
      habits: habits,
      previousHabits: previousHabits,
      lessons: progress == null
          ? null
          : WeeklyReview.datedLessons(progress, start, today),
      previousLessons: progress == null
          ? null
          : WeeklyReview.datedLessons(progress, previous, previousEnd),
      challengeDays: challengeDays,
      previousChallengeDays: previousChallengeDays,
    );
  }
}
