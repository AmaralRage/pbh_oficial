import 'package:supabase_flutter/supabase_flutter.dart';

class PrivateSupportService {
  PrivateSupportService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

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

  Future<List<Map<String, dynamic>>> replies(String id) async => await _client
      .from('private_support_replies')
      .select('id,message,created_at')
      .eq('request_id', id)
      .order('created_at')
      .order('id')
      .limit(100);

  Future<void> reply(String id, String message) async {
    await _client
        .rpc(
          'reply_private_support',
          params: {'p_request': id, 'p_message': message.trim()},
        )
        .timeout(const Duration(seconds: 15));
  }
}
