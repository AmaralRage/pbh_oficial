import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_post_model.dart';

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

  Future<List<CommunityPostModel>> fetchPosts({
    int filterIndex = 0,
    int offset = 0,
    int limit = 20,
    String search = '',
    String? topic,
  }) async {
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
    final rows = await orderedQuery.range(offset, offset + limit - 1);
    var savedIds = <String>{};
    if (auxiliaryDataFuture != null) {
      final auxiliaryData = await auxiliaryDataFuture;
      followingIds = auxiliaryData[0];
      savedIds = auxiliaryData[1].toSet();
    }
    return rows.map((row) {
      final post = CommunityPostModel.fromMap(row);
      return post.copyWith(
        isFollowing: followingIds.contains(post.userId),
        isSaved: savedIds.contains(post.id),
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
  }) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para publicar.');
    await _client.from('community_posts').insert({
      'user_id': userId,
      'content': content.trim(),
      'achievement_tag': achievementTag?.trim().isEmpty == true
          ? null
          : achievementTag?.trim(),
      'topic': topic,
    });
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
