import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';

import '../models/community_post_model.dart';
import '../models/community_photo.dart';
import 'auth_service.dart';
import 'comment_submission_store.dart';

class CommunityBroadcastPending implements Exception {
  const CommunityBroadcastPending();
}

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
    this.likes = 0,
    this.likedByMe = false,
  });

  final String id;
  final String userId;
  final String author;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? replyToId;
  final int likes;
  final bool likedByMe;

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
        likes: (row['likes_count'] as num?)?.toInt() ?? 0,
        likedByMe: row['liked_by_me'] as bool? ?? false,
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

class _CommunityPhotoUrlCache {
  final urls = <String, ({String url, DateTime expires})>{};
  String? account;
}

class CommunityService {
  CommunityService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  final _commentSubmissions = CommentSubmissionStore();

  String? get _userId => _client.auth.currentUser?.id;
  String? get currentUserId => _userId;
  bool get canPin => AuthService.isProjectLeader(_client.auth.currentUser);
  Future<List<Map<String, dynamic>>> mentionCandidates(String query) async {
    final user = _userId;
    if (user == null || query.length < 2) return [];
    final rows =
        await _client.rpc(
              'search_community_members',
              params: {'p_query': '@$query', 'p_offset': 0},
            )
            as List;
    if (_userId != user) throw StateError('A conta mudou.');
    return rows
        .map((r) => Map<String, dynamic>.from(r as Map))
        .where((r) => r['handle'] is String)
        .take(5)
        .toList();
  }

  Future<String?> resolveMention(String handle) async {
    final user = _userId;
    final rows =
        await _client.rpc(
              'resolve_community_handles',
              params: {
                'p_handles': [handle],
              },
            )
            as List;
    if (_userId != user) throw StateError('A conta mudou.');
    return rows.isEmpty ? null : (rows.first as Map)['user_id'] as String?;
  }

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;
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

  static final _photoCaches = Expando<_CommunityPhotoUrlCache>();
  _CommunityPhotoUrlCache get _photoCache =>
      _photoCaches[_client] ??= _CommunityPhotoUrlCache();

  void invalidatePhotoUrls(Iterable<String> paths) {
    for (final path in paths) {
      _photoCache.urls.remove(path);
    }
  }

  Future<Map<String, String>> _photoUrls(List<String> paths) async {
    if (paths.isEmpty) return {};
    final account = _userId;
    if (_photoCache.account != account) {
      _photoCache.urls.clear();
      _photoCache.account = account;
    }
    final now = DateTime.now();
    _photoCache.urls.removeWhere((_, entry) => !entry.expires.isAfter(now));
    final urls = <String, String>{};
    final missing = <String>[];
    for (final path in paths.toSet()) {
      final cached = _photoCache.urls[path];
      if (cached == null) {
        missing.add(path);
      } else {
        urls[path] = cached.url;
      }
    }
    if (missing.isEmpty) return urls;
    try {
      final signed = await _client.storage
          .from('community-photos')
          .createSignedUrls(missing, 600);
      // Keep a safety margin before Storage's ten minute expiry.
      if (_userId != account || _photoCache.account != account) return {};
      for (var i = 0; i < missing.length && i < signed.length; i++) {
        final url = signed[i].signedUrl;
        if (url.isEmpty) continue;
        urls[missing[i]] = url;
        _photoCache.urls[missing[i]] = (
          url: url,
          expires: now.add(const Duration(minutes: 8)),
        );
      }
      while (_photoCache.urls.length > 500) {
        _photoCache.urls.remove(_photoCache.urls.keys.first);
      }
    } catch (_) {
      // A failed signing request must not hide attachments already cached.
    }
    return urls;
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
        : query
              .order('pinned_at', ascending: false, nullsFirst: false)
              .order('created_at', ascending: false);
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

  Future<List<CommunityPostModel>> memberPosts(
    String userId, {
    int offset = 0,
  }) async {
    final account = _userId;
    final rows =
        await _client.rpc(
              'member_publications',
              params: {'p_user': userId, 'p_offset': offset},
            )
            as List;
    final posts = rows
        .map((r) => CommunityPostModel.fromMap(Map<String, dynamic>.from(r)))
        .toList();
    final urls = await _photoUrls(
      posts.expand((p) => p.imagePaths).toSet().toList(),
    );
    if (account != _userId) throw StateError('A conta mudou.');
    return [
      for (final p in posts)
        p.copyWith(
          imageUrls: [for (final path in p.imagePaths) urls[path] ?? ''],
        ),
    ];
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
    String sort = 'recent',
  }) async {
    final query = isSample
        ? _client
              .from('community_sample_comment_feed')
              .select()
              .eq('sample_post_key', postId)
        : _client.from('community_comment_feed').select().eq('post_id', postId);
    final ordered = sort == 'likes'
        ? query.order('likes_count', ascending: false)
        : query;
    final rows = await ordered
        .order('created_at', ascending: sort == 'oldest')
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map((row) => CommunityComment.fromMap(row)).toList();
  }

  Future<List<CommunityComment>> commentContext(
    String post,
    String comment,
  ) async {
    final rows =
        await _client.rpc(
              'community_comment_context',
              params: {'p_id': comment, 'p_post': post},
            )
            as List;
    return rows
        .map(
          (row) =>
              CommunityComment.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> editPublication(
    CommunityPostModel post,
    String content,
    List<String?> retainedPaths,
    List<CommunityPhoto?> photos,
    List<dynamic> framings, {
    void Function(int completed, int total)? onUploadProgress,
  }) async {
    final user = _userId;
    if (user == null || user != post.userId)
      throw StateError('Entre na conta do autor.');
    if (retainedPaths.length > 4 ||
        photos.length != retainedPaths.length ||
        framings.length != retainedPaths.length)
      throw ArgumentError('Anexos inválidos.');
    final revision = newPostId().replaceAll('-', '');
    final paths = <String>[
      for (var i = 0; i < retainedPaths.length; i++)
        retainedPaths[i] ??
            '$user/${post.id}/${i}_$revision.${photos[i]!.extension}',
    ];
    final uploads = [
      for (var i = 0; i < photos.length; i++)
        if (photos[i] != null) paths[i],
    ];
    if (uploads.isNotEmpty) {
      var completed = 0;
      onUploadProgress?.call(0, uploads.length);
      await _client.rpc(
        'prepare_community_post_edit',
        params: {'p_id': post.id, 'p_paths': uploads},
      );
      for (var i = 0; i < photos.length; i++) {
        if (_userId != user) throw StateError('A conta mudou.');
        final photo = photos[i];
        if (photo != null) {
          await _client.storage
              .from('community-photos')
              .uploadBinary(
                paths[i],
                photo.bytes,
                fileOptions: FileOptions(contentType: photo.mime),
              );
          onUploadProgress?.call(++completed, uploads.length);
        }
      }
    }
    if (_userId != user) throw StateError('A conta mudou.');
    await _client.rpc(
      'edit_community_publication',
      params: {
        'p_id': post.id,
        'p_expected': {
          'content': post.content,
          'paths': post.imagePaths,
          'framings': post.imageFramings,
        },
        'p_content': content.trim(),
        'p_paths': paths,
        'p_framings': framings,
      },
    );
  }

  Future<void> editImageFraming(
    CommunityPostModel post,
    List<dynamic> framings,
  ) async {
    await _client.rpc(
      'edit_community_image_framing',
      params: {
        'p_id': post.id,
        'p_expected': post.imageFramings,
        'p_framings': framings,
      },
    );
  }

  Future<void> setCommentLike(
    String id,
    bool liked, {
    bool isSample = false,
  }) async {
    await _client.rpc(
      'set_community_comment_like',
      params: {'p_id': id, 'p_liked': liked, 'p_sample': isSample},
    );
  }

  Future<void> createPost(
    String content, {
    String? achievementTag,
    String? topic,
    List<CommunityPhoto> photos = const [],
    String? draftId,
    void Function(int completed, int total)? onUploadProgress,
    bool notifyMembers = false,
  }) async {
    final id = draftId ?? newPostId();
    final account = _userId;
    if (notifyMembers && !canNotifyMembers)
      throw StateError('Somente o líder pode avisar todos os membros.');
    await _createPost(
      content,
      achievementTag: achievementTag,
      topic: topic,
      photos: photos,
      draftId: id,
      onUploadProgress: onUploadProgress,
    );
    if (notifyMembers) {
      try {
        if (account != _userId) throw StateError('A conta mudou.');
        await _client
            .rpc('queue_community_post_broadcast', params: {'p_post': id})
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        throw const CommunityBroadcastPending();
      }
    }
  }

  bool get canNotifyMembers =>
      AuthService.isProjectLeader(_client.auth.currentUser);

  Future<void> _createPost(
    String content, {
    String? achievementTag,
    String? topic,
    List<CommunityPhoto> photos = const [],
    String? draftId,
    void Function(int completed, int total)? onUploadProgress,
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
        onUploadProgress?.call(0, photos.length);
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
          onUploadProgress?.call(i + 1, photos.length);
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
        if (photos.any((p) => p.framing != null))
          'image_framings': [for (final p in photos) p.framing],
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
    final text = content.trim();
    if (text.isEmpty || text.length > 1000) {
      throw ArgumentError('Escreva até 1000 caracteres.');
    }
    final id = await _commentSubmissions.requestId(
      userId,
      postId,
      text,
      replyToId,
      isSample,
      newPostId,
    );
    if (_userId != userId) throw StateError('A conta mudou.');
    await _client
        .rpc(
          'submit_community_comment',
          params: {
            'p_id': id,
            'p_post': postId,
            'p_content': text,
            'p_reply': replyToId,
            'p_sample': isSample,
          },
        )
        .timeout(const Duration(seconds: 20));
  }

  Future<void> confirmCommentDraftCleared(
    String postId,
    String content, {
    bool isSample = false,
    String? replyToId,
  }) async {
    final user = _userId;
    if (user != null) {
      await _commentSubmissions.acknowledged(
        user,
        postId,
        isSample,
        content.trim(),
        replyToId,
      );
    }
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

  Future<void> editPost(CommunityPostModel post, String content) async {
    if (_userId == null || post.userId != _userId)
      throw StateError('Edite somente sua publicação.');
    await _client.rpc(
      'edit_community_post',
      params: {
        'p_id': post.id,
        'p_content': content,
        'p_expected': post.content,
      },
    );
  }

  Future<void> pinPost(String postId, bool pin) async =>
      _client.rpc('pin_community_post', params: {'p_id': postId, 'p_pin': pin});
  Future<Map<String, dynamic>> activityPreferences() async =>
      Map<String, dynamic>.from(
        await _client.rpc('get_community_activity_preferences') as Map,
      );
  Future<void> saveActivityOptions(
    bool replies,
    bool comments,
    bool likes,
    bool mentions,
  ) async {
    await _client.rpc(
      'set_community_activity_options',
      params: {
        'p_replies': replies,
        'p_comments': comments,
        'p_likes': likes,
        'p_mentions': mentions,
      },
    );
  }

  Future<void> saveActivityPreferences(
    bool replies,
    bool comments,
    bool likes,
  ) async {
    await _client.rpc(
      'set_community_activity_preferences',
      params: {'p_replies': replies, 'p_comments': comments, 'p_likes': likes},
    );
  }

  Future<List<Map<String, dynamic>>> replyActivity() async {
    return activityPage();
  }

  Future<List<Map<String, dynamic>>> activityPage({int offset = 0}) async {
    final user = _userId;
    if (user == null) return [];
    final rows =
        await _client.rpc(
              'community_activity_page',
              params: {'p_offset': offset},
            )
            as List;
    if (_userId != user) throw StateError('A conta mudou.');
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<int> activityUnreadCount() async {
    final user = _userId;
    if (user == null) return 0;
    final count = await _client.rpc('community_activity_unread_count') as num;
    if (_userId != user) throw StateError('A conta mudou.');
    return count.toInt();
  }

  Future<void> markActivityRead(DateTime through) async {
    if (_userId == null) throw StateError('Entre na sua conta.');
    await _client.rpc(
      'mark_community_activity_read',
      params: {'p_through': through.toUtc().toIso8601String()},
    );
  }

  Future<void> readReply(String id) async {
    final user = _userId;
    if (user == null) throw StateError('Entre novamente.');
    await _client
        .from('community_reply_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('recipient_id', user);
  }

  Future<CommunityPostModel?> postById(String id) async {
    final user = _userId;
    final row = await _client
        .from('community_feed')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final post = CommunityPostModel.fromMap(row);
    final urls = await _photoUrls(post.imagePaths);
    if (_userId != user) throw StateError('A conta mudou.');
    return post.copyWith(
      imageUrls: [for (final path in post.imagePaths) urls[path] ?? ''],
    );
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
