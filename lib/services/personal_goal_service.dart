import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalGoalService {
  PersonalGoalService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client {
    _user = _client.auth.currentUser?.id;
  }
  final SupabaseClient _client;
  late final String? _user;
  String? _goalId, _updatedAt;
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
    _goalId = row?['goal_id'] as String?;
    _updatedAt = row?['updated_at'] as String?;
    return row?['completed_at'] != null ? null : row;
  }

  Future<List<Map<String, dynamic>>> entries() async {
    _check();
    var query = _client
        .from('personal_goal_entries')
        .select()
        .eq('user_id', _user!);
    if (_goalId != null) query = query.eq('goal_id', _goalId!);
    final rows = await query
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
        .rpc(
          'save_personal_goal',
          params: {
            'p_title': title.trim(),
            'p_next_step': nextStep.trim(),
            'p_public': isPublic,
            'p_expected_goal': _goalId,
            'p_expected_updated': _updatedAt,
          },
        )
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
          'goal_id': _goalId,
          'content': text.trim(),
        })
        .timeout(const Duration(seconds: 10));
    _check();
  }

  Future<void> complete() async {
    _check();
    await _client.rpc(
      'complete_personal_goal',
      params: {'p_goal': _goalId, 'p_expected_updated': _updatedAt},
    );
    _check();
  }

  Future<List<Map<String, dynamic>>> history({int offset = 0}) async {
    _check();
    final rows = await _client
        .from('personal_goal_history')
        .select()
        .eq('user_id', _user!)
        .order('completed_at', ascending: false)
        .order('id')
        .range(offset, offset + 19);
    _check();
    return rows;
  }

  Future<List<Map<String, dynamic>>> timeline(
    String? goalId, {
    int offset = 0,
  }) async {
    _check();
    var query = _client
        .from('personal_goal_entries')
        .select()
        .eq('user_id', _user!);
    query = goalId == null
        ? query.isFilter('goal_id', null)
        : query.eq('goal_id', goalId);
    final rows = await query
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + 29);
    _check();
    return rows;
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
