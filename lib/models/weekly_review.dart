import '../services/program_service.dart';

class WeeklyReview {
  const WeeklyReview({
    required this.start,
    required this.today,
    required this.habits,
    required this.previousHabits,
    required this.lessons,
    required this.previousLessons,
    required this.challengeDays,
    required this.previousChallengeDays,
  });
  final DateTime start, today;
  final int? habits,
      previousHabits,
      lessons,
      previousLessons,
      challengeDays,
      previousChallengeDays;
  static DateTime monday(DateTime date) =>
      DateTime(date.year, date.month, date.day - date.weekday + 1);
  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static int datedLessons(
    Iterable<ProgramProgress> progress,
    DateTime start,
    DateTime end,
  ) {
    var count = 0;
    for (final state in progress) {
      for (final entry in state.completedAt.entries) {
        final parsed = DateTime.tryParse(entry.value)?.toLocal();
        if (parsed == null || !state.completed.contains(entry.key)) continue;
        final key = dayKey(parsed);
        if (key.compareTo(dayKey(start)) >= 0 &&
            key.compareTo(dayKey(end)) <= 0) {
          count++;
        }
      }
    }
    return count;
  }
}
