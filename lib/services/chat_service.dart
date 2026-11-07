import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';

class ChatService {
  ChatService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;
  final SupabaseClient client;
  String? get userId => client.auth.currentUser?.id;
  void _check(String? user) {
    if (user == null || user != userId)
      throw StateError('A conta mudou. Entre novamente.');
  }

  final _urls = <String, ({String url, DateTime expires})>{};
  String? _cacheAccount;
  Future<List<Map<String, dynamic>>> _identities(List rows, String idKey, String? user) async {
    final mapped = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    if (mapped.isEmpty) return mapped;
    try {
      final identities = await client.rpc('community_member_identities', params: {
        'p_ids': mapped.map((r) => r[idKey] as String).toSet().toList(),
      }).timeout(const Duration(seconds: 10)) as List;
      _check(user);
      final byId = {for (final identity in identities) (identity as Map)['user_id']: identity};
      for (final row in mapped) {
        final identity = byId[row[idKey]];
        if (identity != null) {
          row['avatar_url'] = identity['avatar_url'];
          row['founder'] = identity['founder'] == true;
        }
      }
    } catch (_) {
      // A temporary identity failure must not hide the conversations themselves.
      _check(user);
    }
    return mapped;
  }
  Future<List<ChatThread>> inbox({
    ChatThread? before,
    String? thread,
    String query = '',
  }) async {
    final user = userId;
    final rows =
        await client
                .rpc(
                  'chat_inbox',
                  params: {
                    'p_before': before?.activityAt.toUtc().toIso8601String(),
                    'p_before_id': before?.id,
                    'p_thread': thread,
                    'p_query': query,
                  },
                )
                .timeout(const Duration(seconds: 20))
            as List;
    _check(user);
    final identities = await _identities(rows, 'peer_id', user);
    return identities.map(ChatThread.fromMap).toList();
  }

  Future<int> unread() async {
    final user = userId;
    final result = await client
        .rpc('chat_unread_count')
        .timeout(const Duration(seconds: 15));
    _check(user);
    return (result as num).toInt();
  }

  Future<String> open(String member) async {
    final user = userId;
    final id = await client
        .rpc('chat_open', params: {'p_member': member})
        .timeout(const Duration(seconds: 20));
    _check(user);
    return id as String;
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int offset = 0,
  }) async {
    final user = userId;
    final rows =
        await client
                .rpc(
                  'search_community_members',
                  params: {'p_query': query, 'p_offset': offset},
                )
                .timeout(const Duration(seconds: 15))
            as List;
    _check(user);
    final identities = await _identities(rows, 'user_id', user);
    return identities
        .where((r) => r['user_id'] != user)
        .toList();
  }

  Future<List<ChatMessage>> messages(
    String thread, {
    ChatMessage? before,
  }) async {
    final user = userId;
    if (_cacheAccount != user) {
      _cacheAccount = user;
      _urls.clear();
    }
    final rows =
        await client
                .rpc(
                  'chat_messages_page',
                  params: {
                    'p_thread': thread,
                    'p_before': before?.createdAt.toUtc().toIso8601String(),
                    'p_before_id': before?.id,
                  },
                )
                .timeout(const Duration(seconds: 20))
            as List;
    _check(user);
    _urls.removeWhere((_, v) => v.expires.isBefore(DateTime.now()));
    final paths = rows
        .map((r) => (r as Map)['image_path'])
        .whereType<String>()
        .toSet();
    final missing = paths.where((p) => !_urls.containsKey(p)).toList();
    if (missing.isNotEmpty) {
      try {
        final signed = await client.storage
            .from('chat-photos')
            .createSignedUrls(missing, 60);
        _check(user);
        for (var i = 0; i < missing.length && i < signed.length; i++) {
          if (signed[i].signedUrl.isNotEmpty)
            _urls[missing[i]] = (
              url: signed[i].signedUrl,
              expires: DateTime.now().add(const Duration(seconds: 35)),
            );
        }
      } catch (_) {
        _check(user);
      }
    }
    while (_urls.length > 120) {
      _urls.remove(_urls.keys.first);
    }
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return ChatMessage.fromMap(m, imageUrl: _urls[m['image_path']]?.url);
    }).toList();
  }

  Future<void> send(String thread, ChatDraft draft) async {
    final user = userId;
    _check(user);
    // Confirm an uncertain previous result before uploading the same attachment.
    final prior = await client
        .from('chat_messages')
        .select('id,sender_id,body,reply_to')
        .eq('id', draft.id)
        .eq('thread_id', thread)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    _check(user);
    if (prior != null) {
      if (prior['sender_id'] == user &&
          prior['body'] == draft.text.trim() &&
          prior['reply_to'] == draft.replyId)
        return;
      throw StateError('A mensagem mudou. Revise antes de enviar.');
    }
    String? path;
    if (draft.photo != null) {
      path =
          await client
                  .rpc(
                    'chat_prepare_image',
                    params: {'p_thread': thread, 'p_message': draft.id},
                  )
                  .timeout(const Duration(seconds: 15))
              as String;
      _check(user);
      final existing = await client.storage
          .from('chat-photos')
          .exists(path)
          .timeout(const Duration(seconds: 15));
      if (!existing)
        await client.storage
            .from('chat-photos')
            .uploadBinary(
              path,
              draft.photo!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            )
            .timeout(const Duration(seconds: 30));
      _check(user);
    }
    await client
        .rpc(
          'chat_send',
          params: {
            'p_thread': thread,
            'p_id': draft.id,
            'p_body': draft.text.trim(),
            'p_image': path,
            'p_reply': draft.replyId,
          },
        )
        .timeout(const Duration(seconds: 20));
    _check(user);
  }

  Future<void> markRead(String thread, String through) async {
    final user = userId;
    await client.rpc(
      'chat_mark_read',
      params: {'p_thread': thread, 'p_through': through},
    );
    _check(user);
  }

  Future<void> delete(String id) async {
    final user = userId;
    await client.rpc('chat_delete_message', params: {'p_id': id});
    _check(user);
  }

  RealtimeChannel watchInbox(
    void Function() changed,
    void Function(bool)? connection,
  ) {
    final channel = client.channel(
      'private-chat-inbox-${userId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    for (final event in [
      PostgresChangeEvent.insert,
      PostgresChangeEvent.update,
    ]) {
      channel.onPostgresChanges(
        event: event,
        schema: 'public',
        table: 'chat_threads',
        callback: (_) => changed(),
      );
    }
    return channel.subscribe((status, _) {
      connection?.call(status == RealtimeSubscribeStatus.subscribed);
      if (status == RealtimeSubscribeStatus.subscribed) changed();
    });
  }

  RealtimeChannel watchRoom(
    String thread,
    void Function(bool) changed,
    void Function(bool) connection,
  ) {
    int? revision;
    return client
        .channel(
          'private-chat-room-$thread-${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: thread,
          ),
          callback: (_) => changed(false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_threads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: thread,
          ),
          callback: (event) {
            final next = (event.newRecord['messages_revision'] as num?)
                ?.toInt();
            final reset = revision == null || revision != next;
            revision = next;
            changed(reset);
          },
        )
        .subscribe((status, _) {
          connection(status == RealtimeSubscribeStatus.subscribed);
          if (status == RealtimeSubscribeStatus.subscribed) changed(true);
        });
  }

  Future<void> close(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }
}
