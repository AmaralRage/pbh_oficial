import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import '../models/profile_achievement.dart';

class ProfileAchievementService {
  ProfileAchievementService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<Set<String>> manualAwards() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};
    if (AuthService.isProjectLeader(user)) {
      return ProfileAchievement.supremeSeals.map((seal) => seal.id).toSet();
    }
    try {
      final rows = await _client
          .from('profile_achievement_awards')
          .select('achievement_key')
          .eq('user_id', user.id);
      return rows.map((row) => row['achievement_key'] as String).toSet();
    } on PostgrestException catch (error) {
      // Existing profiles remain usable before the awards migration is applied.
      if (error.code == '42P01' || error.code == 'PGRST205') return {};
      rethrow;
    }
  }

  Future<void> grantSupremeSeal(String email, String achievementKey) async {
    if (!AuthService.isProjectLeader(_client.auth.currentUser)) {
      throw StateError('Somente o líder do projeto pode conceder este selo.');
    }
    await _client.rpc(
      'grant_profile_achievement',
      params: {
        'p_email': email.trim().toLowerCase(),
        'p_achievement_key': achievementKey,
      },
    );
  }
}
