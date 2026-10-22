import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_achievement.dart';
import '../models/profile_style.dart';
import '../models/challenge_model.dart';
import 'auth_service.dart';
import 'challenge_service.dart';
import 'community_service.dart';
import 'habit_service.dart';
import 'profile_achievement_service.dart';

class ProfileUnlocks {
  const ProfileUnlocks(this.completed, this.earned);
  final int completed;
  final List<ProfileAchievement> earned;
}

class ProfileCustomizationService {
  ProfileCustomizationService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;
  final SupabaseClient client;
  Future<ProfileUnlocks> unlocks() async {
    final user = client.auth.currentUser;
    if (user == null)
      throw StateError('Entre na sua conta para personalizar o perfil.');
    final founder = AuthService.isProjectLeader(user);
    final challenges = await ChallengeService(client: client).fetchChallenges();
    final completed = challenges
        .where((c) => c.status == ChallengeStatus.completed)
        .map((c) => c.id)
        .toSet();
    final values = await Future.wait<Object>([
      HabitService(client: client).streak(),
      CommunityService(client: client).followerCount(),
      ProfileAchievementService(client: client).manualAwards(),
    ]);
    final now = DateTime.now();
    final streak = founder
        ? DateTime.utc(
                now.year,
                now.month,
                now.day,
              ).difference(DateTime.utc(2021, 1, 1)).inDays +
              1
        : values[0] as int;
    return ProfileUnlocks(
      completed.length,
      ProfileAchievement.earned(
        isAuthenticated: true,
        isProjectLeader: founder,
        streak: streak,
        completedChallenges: completed.length,
        totalChallenges: challenges.length,
        followers: values[1] as int,
        completedIds: completed,
        manualAwards: values[2] as Set<String>,
      ),
    );
  }

  static String imageType(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024)
      throw ArgumentError('Escolha uma imagem de até 5 MB.');
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10)
      return 'png';
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255)
      return 'jpeg';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP')
      return 'webp';
    throw ArgumentError('Use uma foto PNG, JPEG ou WebP.');
  }

  Future<void> save({
    required String name,
    required String bio,
    required ProfileStyle style,
    Uint8List? photo,
    bool removePhoto = false,
    Uint8List? coverPhoto,
    bool removeCover = false,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sua sessão terminou. Entre novamente.');
    if (name.trim().isEmpty ||
        name.trim().length > 40 ||
        bio.trim().length > 120)
      throw ArgumentError(
        'Confira o nome (até 40 caracteres) e a biografia (até 120).',
      );
    final progress = await unlocks();
    if (client.auth.currentUser?.id != user.id)
      throw StateError('A conta mudou. Abra novamente o perfil.');
    final safeStyle = style.validated(
      founder: AuthService.isProjectLeader(user),
      completed: progress.completed,
      earned: progress.earned,
    );
    final bucket = client.storage.from('profile-avatars');
    final covers = client.storage.from('profile-covers');
    final uploaded = <({String bucket, String path})>[];
    String? avatar;
    String? coverUrl;
    try {
      if (photo != null) {
        final type = imageType(photo);
        final path =
            '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$type';
        await bucket.uploadBinary(
          path,
          photo,
          fileOptions: FileOptions(contentType: 'image/$type', upsert: false),
        );
        uploaded.add((bucket: 'profile-avatars', path: path));
        avatar = bucket.getPublicUrl(path);
      }
      if (coverPhoto != null) {
        final type = imageType(coverPhoto);
        final path =
            '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$type';
        await covers.uploadBinary(
          path,
          coverPhoto,
          fileOptions: FileOptions(contentType: 'image/$type', upsert: false),
        );
        uploaded.add((bucket: 'profile-covers', path: path));
        coverUrl = covers.getPublicUrl(path);
      }
      if (client.auth.currentUser?.id != user.id)
        throw StateError('A conta mudou. Abra novamente o perfil.');
      await client.auth.updateUser(
        UserAttributes(
          data: {
            'display_name': name.trim(),
            'bio': bio.trim(),
            'profile_style': safeStyle.toMap(),
            if (avatar != null || removePhoto) 'avatar_url': avatar ?? '',
            if (coverUrl != null || removeCover) 'cover_url': coverUrl ?? '',
          },
        ),
      );
    } catch (_) {
      for (final upload in uploaded) {
        try {
          await client.storage.from(upload.bucket).remove([upload.path]);
        } catch (_) {}
      }
      rethrow;
    }
    // Remove only this user's previous upload, after the new metadata is saved.
    final previous = user.userMetadata?['avatar_url'];
    final prefix = '${bucket.getPublicUrl('')}${user.id}/';
    if ((avatar != null || removePhoto) &&
        previous is String &&
        previous.startsWith(prefix)) {
      try {
        await bucket.remove([
          '${user.id}/${previous.substring(prefix.length)}',
        ]);
      } catch (_) {}
    }
    final previousCover = user.userMetadata?['cover_url'];
    final coverPrefix = '${covers.getPublicUrl('')}${user.id}/';
    if ((coverUrl != null || removeCover) &&
        previousCover is String &&
        previousCover.startsWith(coverPrefix)) {
      try {
        await covers.remove([
          '${user.id}/${previousCover.substring(coverPrefix.length)}',
        ]);
      } catch (_) {}
    }
  }
}
