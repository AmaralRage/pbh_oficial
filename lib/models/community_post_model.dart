class CommunityPostModel {
  final String id;
  final String userId;
  final String authorName;
  final String? avatarUrl;
  final DateTime createdAt;
  final String content;
  final int likes;
  final int comments;
  final String? achievementTag;
  final bool likedByMe;
  final bool isFollowing;
  final bool isSaved;
  final bool isSample;
  final String? avatarAsset;
  final String? topic;

  const CommunityPostModel({
    required this.id,
    required this.userId,
    required this.authorName,
    this.avatarUrl,
    required this.createdAt,
    required this.content,
    required this.likes,
    required this.comments,
    required this.likedByMe,
    this.isFollowing = false,
    this.isSaved = false,
    this.isSample = false,
    this.avatarAsset,
    this.topic,
    this.achievementTag,
  });

  String get authorInitials {
    final parts = authorName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'M';
    return parts.length == 1
        ? parts.first.substring(0, 1).toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory CommunityPostModel.fromMap(Map<String, dynamic> row) {
    return CommunityPostModel(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      authorName: row['author_name'] as String? ?? 'Membro',
      avatarUrl: row['author_avatar_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      content: row['content'] as String,
      likes: row['likes_count'] as int? ?? 0,
      comments: row['comments_count'] as int? ?? 0,
      likedByMe: row['liked_by_me'] as bool? ?? false,
      achievementTag: row['achievement_tag'] as String?,
      topic: row['topic'] as String?,
    );
  }

  CommunityPostModel copyWith({bool? isFollowing, bool? isSaved}) =>
      CommunityPostModel(
        id: id,
        userId: userId,
        authorName: authorName,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
        content: content,
        likes: likes,
        comments: comments,
        likedByMe: likedByMe,
        achievementTag: achievementTag,
        isFollowing: isFollowing ?? this.isFollowing,
        isSaved: isSaved ?? this.isSaved,
        isSample: isSample,
        avatarAsset: avatarAsset,
        topic: topic,
      );
}
