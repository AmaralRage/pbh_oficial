import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';

import '../models/community_post_model.dart';
import '../models/community_photo.dart';

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.userId,
    required this.author,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.replyToId,
  });

  final String id;
  final String userId;
  final String author;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? replyToId;

  factory CommunityComment.fromMap(Map<String, dynamic> row) =>
      CommunityComment(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        author: row['author_name'] as String? ?? 'Membro',
        avatarUrl: row['author_avatar_url'] as String?,
        content: row['content'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        editedAt: DateTime.tryParse(
          row['edited_at'] as String? ?? '',
        )?.toLocal(),
        replyToId: row['reply_to_id'] as String?,
      );
}

class CommunityStats {
  const CommunityStats({
    required this.posts,
    required this.comments,
    required this.likes,
  });
  final int posts;
  final int comments;
  final int likes;
}

class CommunityService {
  CommunityService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;
  String? get currentUserId => _userId;
  String get currentUserName {
    final name =
        (_client.auth.currentUser?.userMetadata?['display_name'] as String?)
            ?.trim();
    return name?.isNotEmpty == true ? name! : 'Membro';
  }

  bool _cleaningPhotos = false;
  DateTime? _lastPhotoCleanup;
  static String newPostId() {
    final random = Random.secure(), bytes = List.generate(16, (_) => 0);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, String>> _photoUrls(List<String> paths) async {
    if (paths.isEmpty) return {};
    try {
      final signed = await _client.storage
          .from('community-photos')
          .createSignedUrls(paths, 600);
      return {
        for (var i = 0; i < paths.length && i < signed.length; i++)
          paths[i]: signed[i].signedUrl,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> cleanupPhotos({bool force = false}) async {
    final user = _userId;
    if (user == null ||
        _cleaningPhotos ||
        (!force &&
            _lastPhotoCleanup != null &&
            DateTime.now().difference(_lastPhotoCleanup!) <
                const Duration(minutes: 1)))
      return;
    _cleaningPhotos = true;
    _lastPhotoCleanup = DateTime.now();
    try {
      final rows = await _client.rpc('pending_community_photo_cleanup') as List;
      for (final row in rows) {
        if (_userId != user) return;
        await _client.storage
            .from('community-photos')
            .remove(List<String>.from(row['paths'] as List));
        if (_userId != user) return;
        await _client.rpc(
          'ack_community_photo_cleanup',
          params: {'p_id': row['post_id']},
        );
      }
    } catch (_) {
      /* Queued cleanup is retried on a later community visit. */
    } finally {
      _cleaningPhotos = false;
    }
  }

  Future<List<CommunityPostModel>> fetchPosts({
    int filterIndex = 0,
    int offset = 0,
    int limit = 20,
    String search = '',
    String? topic,
  }) async {
    unawaited(cleanupPhotos());
    var query = _client.from('community_feed').select();
    final userId = _userId;
    var followingIds = <String>[];
    var savedPostIds = <String>[];
    if (filterIndex == 1) {
      if (userId == null) return const [];
      followingIds = await _fetchFollowingIds(userId);
      if (followingIds.isEmpty) return const [];
      query = query.inFilter('user_id', followingIds);
    } else if (filterIndex == 2) {
      query = query.or('achievement_tag.not.is.null,topic.eq.conquistas');
    } else if (filterIndex == 4) {
      if (userId == null) return const [];
      savedPostIds = await _fetchSavedPostIds(userId);
      if (savedPostIds.isEmpty) return const [];
      query = query.inFilter('id', savedPostIds);
    }
    final term = search.trim().replaceAll(RegExp(r'[,.*()"%_]'), ' ').trim();
    if (term.isNotEmpty)
      query = query.or(
        'content.ilike.%$term%,author_name.ilike.%$term%,topic.ilike.%$term%',
      );
    if (topic != null && topic.isNotEmpty) query = query.eq('topic', topic);
    final orderedQuery = filterIndex == 3
        ? query
              .order('likes_count', ascending: false)
              .order('created_at', ascending: false)
        : query.order('created_at', ascending: false);
    final auxiliaryDataFuture = userId == null
        ? null
        : Future.wait<List<String>>([
            filterIndex == 1
                ? Future.value(followingIds)
                : _fetchFollowingIds(userId),
            filterIndex == 4
                ? Future.value(savedPostIds)
                : _fetchSavedPostIds(userId),
          ]);
    final rows = await orderedQuery
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    final models = rows.map((row) => CommunityPostModel.fromMap(row)).toList();
    final urls = await _photoUrls(
      models.expand((post) => post.imagePaths).toSet().toList(),
    );
    var savedIds = <String>{};
    if (auxiliaryDataFuture != null) {
      final auxiliaryData = await auxiliaryDataFuture;
      followingIds = auxiliaryData[0];
      savedIds = auxiliaryData[1].toSet();
    }
    if (_userId != userId)
      throw StateError('A conta mudou. Atualize a comunidade.');
    return models.map((post) {
      return post.copyWith(
        isFollowing: followingIds.contains(post.userId),
        isSaved: savedIds.contains(post.id),
        imageUrls: [for (final path in post.imagePaths) urls[path] ?? ''],
      );
    }).toList();
  }

  Future<CommunityStats> fetchStats() async {
    final result = await _client.rpc('community_stats') as Map<String, dynamic>;
    return CommunityStats(
      posts: (result['posts'] as num).toInt(),
      comments: (result['comments'] as num).toInt(),
      likes: (result['likes'] as num).toInt(),
    );
  }

  Future<Map<String, dynamic>> fetchSamplePostInteraction(
    String samplePostKey,
  ) async {
    final row = await _client
        .from('community_sample_post_feed')
        .select('likes_count, liked_by_me, comments_count')
        .eq('sample_post_key', samplePostKey)
        .single();
    return row;
  }

  Future<List<String>> _fetchFollowingIds(String userId) async {
    final rows = await _client
        .from('community_follows')
        .select('followed_id')
        .eq('follower_id', userId);
    return rows.map((row) => row['followed_id'] as String).toList();
  }

  Future<List<String>> _fetchSavedPostIds(String userId) async {
    final rows = await _client
        .from('community_saved_posts')
        .select('post_id')
        .eq('user_id', userId);
    return rows.map((row) => row['post_id'] as String).toList();
  }

  Future<List<CommunityComment>> fetchComments(
    String postId, {
    bool isSample = false,
    int offset = 0,
    int limit = 30,
  }) async {
    final query = isSample
        ? _client
              .from('community_sample_comment_feed')
              .select()
              .eq('sample_post_key', postId)
        : _client.from('community_comment_feed').select().eq('post_id', postId);
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((row) => CommunityComment.fromMap(row)).toList();
  }

  Future<void> createPost(
    String content, {
    String? achievementTag,
    String? topic,
    List<CommunityPhoto> photos = const [],
    String? draftId,
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para publicar.');
    if (content.trim().isEmpty || content.trim().length > 2000)
      throw ArgumentError('Escreva um relato de até 2000 caracteres.');
    if (photos.length > CommunityPhoto.maxCount)
      throw ArgumentError('Escolha até quatro fotos.');
    final id = draftId ?? newPostId();
    final paths = [
      for (var i = 0; i < photos.length; i++)
        '$userId/$id/$i.${photos[i].extension}',
    ];
    try {
      final existing = await _client
          .from('community_posts')
          .select('id')
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();
      if (existing != null) return;
      if (photos.isNotEmpty) {
        await _client.rpc(
          'prepare_community_photos',
          params: {'p_id': id, 'p_paths': paths},
        );
        if (_userId != userId)
          throw StateError('A conta mudou. Abra novamente a publicação.');
        await _client.storage.from('community-photos').remove(paths);
        for (var i = 0; i < photos.length; i++) {
          if (_userId != userId)
            throw StateError('A conta mudou. Abra novamente a publicação.');
          await _client.storage
              .from('community-photos')
              .uploadBinary(
                paths[i],
                photos[i].bytes,
                fileOptions: FileOptions(contentType: photos[i].mime),
              );
        }
      }
      if (_userId != userId)
        throw StateError('A conta mudou. Abra novamente a publicação.');
      await _client.from('community_posts').insert({
        'id': id,
        'user_id': userId,
        'content': content.trim(),
        'achievement_tag': achievementTag?.trim().isEmpty == true
            ? null
            : achievementTag?.trim(),
        'topic': topic,
        'image_paths': paths,
      });
    } catch (_) {
      // A lost response can mean the insert committed. Never delete its photos
      // or duplicate the post; the same draft ID can safely be retried.
      if (_userId == userId) {
        try {
          final saved = await _client
              .from('community_posts')
              .select('id')
              .eq('id', id)
              .eq('user_id', userId)
              .maybeSingle();
          if (saved != null) return;
        } catch (_) {
          /* Reservation retains unfinished uploads for cleanup. */
        }
      }
      rethrow;
    }
  }

  Future<void> toggleLike(
    String postId,
    bool currentlyLiked, {
    bool isSample = false,
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para curtir.');
    final table = isSample
        ? 'community_sample_post_likes'
        : 'community_post_likes';
    final postColumn = isSample ? 'sample_post_key' : 'post_id';
    if (currentlyLiked) {
      await _client
          .from(table)
          .delete()
          .eq(postColumn, postId)
          .eq('user_id', userId);
    } else {
      await _client
          .from(table)
          .upsert(
            {postColumn: postId, 'user_id': userId},
            onConflict: '$postColumn,user_id',
            ignoreDuplicates: true,
          );
    }
  }

  Future<void> addComment(
    String postId,
    String content, {
    bool isSample = false,
    String? replyToId,
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para comentar.');
    final table = isSample ? 'community_sample_comments' : 'community_comments';
    final postColumn = isSample ? 'sample_post_key' : 'post_id';
    await _client.from(table).insert({
      postColumn: postId,
      'user_id': userId,
      'content': content.trim(),
      if (replyToId != null) 'reply_to_id': replyToId,
    });
  }

  Future<void> editComment(
    String id,
    String content, {
    bool isSample = false,
  }) async {
    if (_userId == null) throw StateError('Entre na sua conta para editar.');
    if (content.trim().isEmpty || content.trim().length > 1000)
      throw ArgumentError('Escreva até 1000 caracteres.');
    await _client.rpc(
      'edit_community_comment',
      params: {'p_id': id, 'p_content': content.trim(), 'p_sample': isSample},
    );
  }

  Future<void> deleteComment(String commentId, {bool isSample = false}) async {
    final userId = _userId;
    if (userId == null)
      throw StateError('Entre na sua conta para excluir o comentário.');
    final table = isSample ? 'community_sample_comments' : 'community_comments';
    await _client
        .from(table)
        .delete()
        .eq('id', commentId)
        .eq('user_id', userId);
  }

  Future<bool> isSaved(String postId) async {
    final userId = _userId;
    if (userId == null) return false;
    final row = await _client
        .from('community_saved_posts')
        .select('post_id')
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();
    return row != null;
  }

  Future<void> toggleSaved(String postId, bool saved) async {
    final userId = _userId;
    if (userId == null)
      throw StateError('Entre na sua conta para salvar publica��es.');
    if (saved) {
      await _client
          .from('community_saved_posts')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } else {
      await _client.from('community_saved_posts').insert({
        'user_id': userId,
        'post_id': postId,
      });
    }
  }

  Future<void> report(String postId, {required String reason}) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para denunciar.');
    await _client.from('community_reports').insert({
      'reporter_id': userId,
      'post_id': postId,
      'reason': reason,
    });
  }

  Future<void> blockMember(String userId) async {
    final blockerId = _userId;
    if (blockerId == null)
      throw StateError('Entre na sua conta para bloquear membros.');
    if (blockerId == userId)
      throw StateError('Você não pode bloquear a própria conta.');
    await _client
        .from('community_blocks')
        .upsert(
          {'blocker_id': blockerId, 'blocked_id': userId},
          onConflict: 'blocker_id,blocked_id',
          ignoreDuplicates: true,
        );
  }

  Future<void> unblockMember(String userId) async {
    final blockerId = _userId;
    if (blockerId == null)
      throw StateError('Entre na sua conta para desbloquear membros.');
    await _client
        .from('community_blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', userId);
  }

  Future<void> deleteOwnPost(String postId) async {
    final userId = _userId;
    if (userId == null)
      throw StateError('Entre na sua conta para excluir publica��es.');
    await _client
        .from('community_posts')
        .delete()
        .eq('id', postId)
        .eq('user_id', userId);
    await cleanupPhotos(force: true);
  }

  Future<bool> isFollowing(String userId) async {
    final followerId = _userId;
    if (followerId == null || followerId == userId) return false;
    final row = await _client
        .from('community_follows')
        .select('followed_id')
        .eq('follower_id', followerId)
        .eq('followed_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> toggleFollow(String userId, bool currentlyFollowing) async {
    final followerId = _userId;
    if (followerId == null)
      throw StateError('Entre na sua conta para seguir membros.');
    if (currentlyFollowing) {
      await _client
          .from('community_follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('followed_id', userId);
    } else {
      await _client.from('community_follows').insert({
        'follower_id': followerId,
        'followed_id': userId,
      });
    }
  }

  Future<int> followerCount() async {
    final userId = _userId;
    if (userId == null) return 0;
    final rows = await _client
        .from('community_follows')
        .select('follower_id')
        .eq('followed_id', userId);
    return rows.length;
  }
}
