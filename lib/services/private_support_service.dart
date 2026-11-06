import 'package:supabase_flutter/supabase_flutter.dart';

class PrivateSupportService {
  PrivateSupportService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  String? get currentUserId => _client.auth.currentUser?.id;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<String> submit({required String kind, required String message}) async {
    return await _client
            .rpc(
              'submit_private_support_request',
              params: {'p_kind': kind, 'p_message': message.trim()},
            )
            .timeout(const Duration(seconds: 15))
        as String;
  }

  Future<List<Map<String, dynamic>>> requests(int offset) async => await _client
      .from('private_support_requests')
      .select('id,kind,message,created_at,resolved')
      .eq('user_id', _client.auth.currentUser?.id ?? '')
      .order('created_at', ascending: false)
      .order('id')
      .range(offset, offset + 29);

  Future<List<Map<String, dynamic>>> replies(
    String id, {
    int offset = 0,
  }) async => await _client
      .from('private_support_replies')
      .select('id,message,created_at')
      .eq('request_id', id)
      .order('created_at', ascending: false)
      .order('id', ascending: false)
      .range(offset, offset + 29);

  Future<int> unreadCount() async {
    if (_client.auth.currentUser == null) return 0;
    return (await _client.rpc('support_reply_unread_count') as num).toInt();
  }

  Future<Map<String, dynamic>?> latestUnreadRequest() async {
    final result = await _client.rpc('latest_unread_support_request');
    return result == null ? null : Map<String, dynamic>.from(result as Map);
  }

  Future<void> markRepliesRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.rpc('mark_support_replies_read', params: {'p_ids': ids});
  }

  Future<void> reply(String id, String message) async {
    await _client
        .rpc(
          'reply_private_support',
          params: {'p_request': id, 'p_message': message.trim()},
        )
        .timeout(const Duration(seconds: 15));
  }
}
