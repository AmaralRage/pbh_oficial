import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/public_member_profile.dart';

class PublicMemberProfileService {
  PublicMemberProfileService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;
  final SupabaseClient client;
  Future<PublicMemberProfile?> fetch(String id) async {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
    ).hasMatch(id))
      return null;
    final viewer = client.auth.currentUser?.id;
    final data = await client
        .rpc('community_member_profile', params: {'p_user_id': id})
        .timeout(const Duration(seconds: 15));
    if (viewer != client.auth.currentUser?.id)
      throw StateError('A conta mudou. Abra novamente este perfil.');
    if (data == null) return null;
    return PublicMemberProfile.fromMap(Map<String, dynamic>.from(data as Map));
  }
}
