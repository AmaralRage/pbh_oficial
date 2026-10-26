import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalGoalService {
  PersonalGoalService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client {
    _user = _client.auth.currentUser?.id;
  }
  final SupabaseClient _client;
  late final String? _user;
  void _check() {
    if (_user == null || _user != _client.auth.currentUser?.id) {
      throw StateError('Entre novamente na sua conta.');
    }
  }

  Future<Map<String, dynamic>?> load() async {
    _check();
    final row = await _client
        .from('personal_goals')
        .select()
        .eq('user_id', _user!)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    _check();
    return row;
  }

  Future<List<Map<String, dynamic>>> entries() async {
    _check();
    final rows = await _client
        .from('personal_goal_entries')
        .select()
        .eq('user_id', _user!)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(30)
        .timeout(const Duration(seconds: 10));
    _check();
    return rows;
  }

  Future<void> save(String title, String nextStep, bool isPublic) async {
    _check();
    if (title.trim().isEmpty ||
        title.trim().length > 180 ||
        nextStep.trim().length > 300) {
      throw ArgumentError('Revise o objetivo.');
    }
    await _client
        .from('personal_goals')
        .upsert({
          'user_id': _user,
          'title': title.trim(),
          'next_step': nextStep.trim(),
          'is_public': isPublic,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .timeout(const Duration(seconds: 10));
    _check();
  }

  Future<void> addEntry(String goalTitle, String text) async {
    _check();
    if (text.trim().isEmpty || text.trim().length > 1000) {
      throw ArgumentError('Escreva um avanço de até 1000 caracteres.');
    }
    await _client
        .from('personal_goal_entries')
        .insert({
          'user_id': _user,
          'goal_title': goalTitle,
          'content': text.trim(),
        })
        .timeout(const Duration(seconds: 10));
    _check();
  }

  Future<Map<String, dynamic>?> publicGoal(String userId) async {
    final viewer = _client.auth.currentUser?.id;
    final result = await _client
        .rpc('public_profile_goal', params: {'p_user_id': userId})
        .timeout(const Duration(seconds: 10));
    if (viewer != _client.auth.currentUser?.id) {
      throw StateError('A conta mudou.');
    }
    return result == null ? null : Map<String, dynamic>.from(result as Map);
  }
}
