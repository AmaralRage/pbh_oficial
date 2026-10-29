import 'profile_achievement.dart';
import 'profile_style.dart';

class PublicMemberProfile {
  const PublicMemberProfile({
    required this.id,
    required this.name,
    required this.bio,
    required this.style,
    required this.founder,
    required this.isOwn,
    required this.progressShared,
    required this.earned,
    this.avatarUrl,
    this.coverUrl,
    this.completed,
    this.total,
    this.followers,
    this.streak,
  });
  final String id, name, bio;
  final String? avatarUrl, coverUrl;
  final ProfileStyle style;
  final bool founder, isOwn, progressShared;
  final List<ProfileAchievement> earned;
  final int? completed, total, followers, streak;
  bool get hasProgress => completed != null;
  factory PublicMemberProfile.fromMap(Map<String, dynamic> data) {
    final founder = data['founder'] == true;
    final raw = data['progress'];
    final progress =
        raw is Map &&
            (data['progress_shared'] == true || data['is_own'] == true)
        ? raw
        : null;
    int number(String key) => (progress?[key] as num?)?.toInt() ?? 0;
    Set<String> strings(String key) => progress?[key] is List
        ? (progress![key] as List).whereType<String>().toSet()
        : {};
    final earned = progress == null
        ? <ProfileAchievement>[]
        : ProfileAchievement.earned(
            isAuthenticated: true,
            isProjectLeader: founder,
            streak: number('streak'),
            completedChallenges: number('completed'),
            totalChallenges: number('total'),
            followers: number('followers'),
            completedIds: strings('completed_ids'),
            manualAwards: strings('manual_awards'),
          );
    var style = ProfileStyle.fromMetadata({
      'profile_style': data['style'],
    }, founder: founder);
    if (progress != null) {
      style = style.validated(
        founder: founder,
        completed: number('completed'),
        earned: earned,
        manualAwards: strings('manual_awards'),
      );
    } else {
      // Cosmetic unlocks are sanitized by the RPC without exposing hidden counts.
      style = style.copyWith(
        title: founder ? 'founder' : 'member',
        featured: [],
      );
    }
    return PublicMemberProfile(
      id: data['id'] as String,
      name: data['name'] as String? ?? 'Membro',
      bio: data['bio'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String?,
      coverUrl: data['cover_url'] as String?,
      founder: founder,
      isOwn: data['is_own'] == true,
      progressShared: data['progress_shared'] == true,
      style: style,
      earned: earned,
      completed: progress == null ? null : number('completed'),
      total: progress == null ? null : number('total'),
      followers: progress == null ? null : number('followers'),
      streak: progress == null ? null : number('streak'),
    );
  }
}
