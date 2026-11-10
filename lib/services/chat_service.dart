import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../models/chat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _audioCache = <String, Uint8List>{};
  String? _audioAccount;
  String? _cacheAccount;
  Future<List<Map<String, dynamic>>> _identities(
    List rows,
    String idKey,
    String? user,
  ) async {
    final mapped = rows
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    if (mapped.isEmpty) return mapped;
    try {
      final identities =
          await client
                  .rpc(
                    'community_member_identities',
                    params: {
                      'p_ids': mapped
                          .map((r) => r[idKey] as String)
                          .toSet()
                          .toList(),
                    },
                  )
                  .timeout(const Duration(seconds: 10))
              as List;
      _check(user);
      final byId = {
        for (final identity in identities)
          (identity as Map)['user_id']: identity,
      };
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
                  'chat_inbox_v2',
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
    return identities.where((r) => r['user_id'] != user).toList();
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
        .select('id,sender_id,body,reply_to,image_path,audio_path,audio_format')
        .eq('id', draft.id)
        .eq('thread_id', thread)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    _check(user);
    if (prior != null) {
      if (prior['sender_id'] == user &&
          prior['body'] == draft.text.trim() &&
          prior['reply_to'] == draft.replyId &&
          (draft.voice == null
              ? prior['audio_path'] == null &&
                    (draft.photo == null ||
                        prior['image_path'] == '$user/$thread/${draft.id}.jpg')
              : prior['audio_path'] ==
                        '$user/$thread/${draft.id}.${draft.voice!.format}' &&
                    prior['audio_format'] == draft.voice!.format))
        return;
      throw StateError('A mensagem mudou. Revise antes de enviar.');
    }
    String? path;
    final voice = draft.voice;
    if (voice != null) {
      if (voice.bytes.isEmpty ||
          voice.bytes.length > 1048576 ||
          voice.durationMs < 1 ||
          voice.durationMs > 120000 ||
          !['m4a', 'webm'].contains(voice.format) ||
          draft.photo != null ||
          draft.text.trim().isNotEmpty)
        throw StateError('Grave um áudio de até dois minutos.');
      path =
          await client
                  .rpc(
                    'chat_prepare_audio',
                    params: {
                      'p_thread': thread,
                      'p_message': draft.id,
                      'p_format': voice.format,
                    },
                  )
                  .timeout(const Duration(seconds: 15))
              as String;
      _check(user);
      final bucket = client.storage.from('chat-audio');
      if (!await bucket.exists(path).timeout(const Duration(seconds: 15))) {
        _check(user);
        await bucket
            .uploadBinary(
              path,
              voice.bytes,
              fileOptions: FileOptions(
                contentType: voice.contentType,
                upsert: false,
              ),
            )
            .timeout(const Duration(seconds: 30));
      }
      _check(user);
      await client.functions
          .invoke('validate-chat-audio', body: {'path': path})
          .timeout(const Duration(seconds: 25));
      _check(user);
      await client
          .rpc(
            'chat_send_audio',
            params: {
              'p_thread': thread,
              'p_id': draft.id,
              'p_audio': path,
              'p_reply': draft.replyId,
            },
          )
          .timeout(const Duration(seconds: 20));
      _check(user);
      return;
    }
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

  Future<Uint8List> audio(String thread, ChatMessage message) async {
    final user = userId;
    _check(user);
    if (_audioAccount != user) {
      _audioAccount = user;
      _audioCache.clear();
    }
    if (message.audioPath == null) throw StateError('Áudio indisponível.');
    // Check current RLS visibility on every play, including cached recordings.
    final visible = await client
        .from('chat_messages')
        .select('audio_path')
        .eq('id', message.id)
        .eq('thread_id', thread)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    _check(user);
    if (visible == null || visible['audio_path'] != message.audioPath)
      throw StateError('Áudio indisponível ou expirado.');
    final cached = _audioCache[message.audioPath];
    if (cached != null) return cached;
    final bytes = await client.storage
        .from('chat-audio')
        .download(message.audioPath!)
        .timeout(const Duration(seconds: 25));
    _check(user);
    if (bytes.isEmpty || bytes.length > 1048576)
      throw StateError('Áudio inválido.');
    while (_audioCache.values.fold<int>(0, (sum, b) => sum + b.length) +
                bytes.length >
            8 * 1048576 &&
        _audioCache.isNotEmpty) {
      _audioCache.remove(_audioCache.keys.first);
    }
    _audioCache[message.audioPath!] = bytes;
    return bytes;
  }

  Future<Uint8List> photo(String thread, ChatMessage message) async {
    final user = userId;
    _check(user);
    if (message.imagePath == null) throw StateError('Foto indisponível.');
    Future<void> checkVisible() async {
      final row = await client
          .from('chat_messages')
          .select('image_path')
          .eq('id', message.id)
          .eq('thread_id', thread)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      _check(user);
      if (row == null ||
          row['image_path'] != message.imagePath ||
          !message.expiresAt.isAfter(DateTime.now()))
        throw StateError('Foto indisponível ou expirada.');
    }

    await checkVisible();
    final bytes = await client.storage
        .from('chat-photos')
        .download(message.imagePath!)
        .timeout(const Duration(seconds: 25));
    _check(user);
    if (bytes.length < 3 ||
        bytes.length > 524288 ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[2] != 0xff)
      throw StateError('Foto inválida.');
    // Recheck after the request: an account change, expiry or block cancels export.
    await checkVisible();
    return bytes;
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

  Future<void> typing(String thread, bool active) async {
    final user = userId;
    _check(user);
    await client
        .rpc(
          'chat_set_typing',
          params: {'p_thread': thread, 'p_active': active},
        )
        .timeout(const Duration(seconds: 5));
    _check(user);
  }

  Future<DateTime?> peerTyping(String thread) async {
    final user = userId;
    final rows = await client
        .from('chat_typing')
        .select('until_at')
        .eq('thread_id', thread)
        .neq('user_id', user!)
        .limit(1)
        .timeout(const Duration(seconds: 5));
    _check(user);
    return rows.isEmpty
        ? null
        : DateTime.tryParse(rows.first['until_at'] as String);
  }

  RealtimeChannel watchTyping(String thread, void Function() changed) => client
      .channel('chat-typing-$thread-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_typing',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'thread_id',
          value: thread,
        ),
        callback: (_) => changed(),
      )
      .subscribe((status, _) {
        if (status == RealtimeSubscribeStatus.subscribed) changed();
      });

  Future<bool> muted(String thread) async {
    final user = userId;
    final row = await client
        .from('chat_preferences')
        .select('muted')
        .eq('thread_id', thread)
        .eq('user_id', user!)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    _check(user);
    final muted = row?['muted'] == true;
    await SharedPreferencesAsync().setBool(
      'pbh.chat.muted.$user.$thread',
      muted,
    );
    _check(user);
    return muted;
  }

  Future<void> setMuted(String thread, bool value) async {
    final user = userId;
    await client
        .rpc('chat_set_muted', params: {'p_thread': thread, 'p_muted': value})
        .timeout(const Duration(seconds: 10));
    _check(user);
    await SharedPreferencesAsync().setBool(
      'pbh.chat.muted.$user.$thread',
      value,
    );
  }

  Future<List<ChatMessage>> searchMessages(
    String thread,
    String query, {
    ChatMessage? before,
  }) async {
    final user = userId;
    final rows =
        await client
                .rpc(
                  'chat_search_messages',
                  params: {
                    'p_thread': thread,
                    'p_query': query,
                    'p_before': before?.createdAt.toUtc().toIso8601String(),
                    'p_before_id': before?.id,
                  },
                )
                .timeout(const Duration(seconds: 15))
            as List;
    _check(user);
    return rows
        .map((r) => ChatMessage.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<ChatMessage>> replyContext(
    String thread,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final user = userId;
    final rows =
        await client
                .rpc(
                  'chat_reply_context',
                  params: {'p_thread': thread, 'p_ids': ids.take(40).toList()},
                )
                .timeout(const Duration(seconds: 10))
            as List;
    _check(user);
    return rows
        .map((r) => ChatMessage.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }
}
