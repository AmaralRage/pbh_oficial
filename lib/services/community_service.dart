import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_post_model.dart';

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.userId,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String author;
  final String content;
  final DateTime createdAt;

  factory CommunityComment.fromMap(Map<String, dynamic> row) => CommunityComment(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        author: row['author_name'] as String? ?? 'Membro',
        content: row['content'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
}

class CommunityStats {
  const CommunityStats({required this.posts, required this.comments, required this.likes});
  final int posts;
  final int comments;
  final int likes;
}

class CommunityService {
  CommunityService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;
  String? get currentUserId => _userId;

  Future<List<CommunityPostModel>> fetchPosts({int filterIndex = 0}) async {
    var query = _client.from('community_feed').select();
    final userId = _userId;
    var followingIds = <String>[];
    if (filterIndex == 1) {
      if (userId == null) return const [];
      final rows = await _client.from('community_follows').select('followed_id').eq('follower_id', userId);
      followingIds = rows.map((row) => row['followed_id'] as String).toList();
      if (followingIds.isEmpty) return const [];
      query = query.inFilter('user_id', followingIds);
    } else if (filterIndex == 2) {
      query = query.not('achievement_tag', 'is', null);
    }
    final rows = await (filterIndex == 3
        ? query.order('likes_count', ascending: false).order('created_at', ascending: false)
        : query.order('created_at', ascending: false));
    var savedIds = <String>{};
    if (userId != null) {
      if (filterIndex != 1) {
        final follows = await _client.from('community_follows').select('followed_id').eq('follower_id', userId);
        followingIds = follows.map((row) => row['followed_id'] as String).toList();
      }
      final saved = await _client.from('community_saved_posts').select('post_id').eq('user_id', userId);
      savedIds = saved.map((row) => row['post_id'] as String).toSet();
    }
    return rows.map((row) {
      final post = CommunityPostModel.fromMap(row);
      return post.copyWith(isFollowing: followingIds.contains(post.userId), isSaved: savedIds.contains(post.id));
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

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final rows = await _client.from('community_comment_feed').select().eq('post_id', postId).order('created_at');
    return rows.map((row) => CommunityComment.fromMap(row)).toList();
  }

  Future<void> createPost(String content, {String? achievementTag}) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para publicar.');
    await _client.from('community_posts').insert({
      'user_id': userId,
      'content': content.trim(),
      'achievement_tag': achievementTag?.trim().isEmpty == true ? null : achievementTag?.trim(),
    });
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para curtir.');
    final query = _client.from('community_post_likes').delete().eq('post_id', postId).eq('user_id', userId);
    if (currentlyLiked) {
      await query;
    } else {
      await _client.from('community_post_likes').insert({'post_id': postId, 'user_id': userId});
    }
  }

  Future<void> addComment(String postId, String content) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para comentar.');
    await _client.from('community_comments').insert({'post_id': postId, 'user_id': userId, 'content': content.trim()});
  }

  Future<bool> isSaved(String postId) async {
    final userId = _userId;
    if (userId == null) return false;
    final row = await _client.from('community_saved_posts').select('post_id').eq('user_id', userId).eq('post_id', postId).maybeSingle();
    return row != null;
  }

  Future<void> toggleSaved(String postId, bool saved) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para salvar publicações.');
    if (saved) {
      await _client.from('community_saved_posts').delete().eq('user_id', userId).eq('post_id', postId);
    } else {
      await _client.from('community_saved_posts').insert({'user_id': userId, 'post_id': postId});
    }
  }

  Future<void> report(String postId) async {
    final userId = _userId;
    if (userId == null) throw StateError('Entre na sua conta para denunciar.');
    await _client.from('community_reports').insert({'reporter_id': userId, 'post_id': postId});
  }

  Future<bool> isFollowing(String userId) async {
    final followerId = _userId;
    if (followerId == null || followerId == userId) return false;
    final row = await _client.from('community_follows').select('followed_id').eq('follower_id', followerId).eq('followed_id', userId).maybeSingle();
    return row != null;
  }

  Future<void> toggleFollow(String userId, bool currentlyFollowing) async {
    final followerId = _userId;
    if (followerId == null) throw StateError('Entre na sua conta para seguir membros.');
    if (currentlyFollowing) {
      await _client.from('community_follows').delete().eq('follower_id', followerId).eq('followed_id', userId);
    } else {
      await _client.from('community_follows').insert({'follower_id': followerId, 'followed_id': userId});
    }
  }

  Future<int> followerCount() async {
    final userId = _userId;
    if (userId == null) return 0;
    final rows = await _client.from('community_follows').select('follower_id').eq('followed_id', userId);
    return rows.length;
  }
}
