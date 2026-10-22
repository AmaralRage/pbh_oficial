import 'package:flutter/material.dart';
import 'profile_achievement.dart';

class ProfileStyleOption {
  const ProfileStyleOption(
    this.id,
    this.label,
    this.color, {
    this.minimum = 0,
    this.badge,
    this.founderOnly = false,
  });
  final String id;
  final String label;
  final Color color;
  final int minimum;
  final String? badge;
  final bool founderOnly;
  bool available(bool founder, int completed, Set<String> earned) => founderOnly
      ? founder
      : (founder ||
            (completed >= minimum &&
                (badge == null || earned.contains(badge))));
  String get requirement => founderOnly
      ? 'Exclusivo do fundador'
      : badge != null
      ? 'Conquiste a Platina PBH'
      : '$minimum desafios concluídos';
}

class ProfileStyle {
  const ProfileStyle({
    this.frame = 'orange',
    this.cover = 'ember',
    this.title = 'member',
    this.featured,
  });
  final String frame;
  final String cover;
  final String title;
  final List<String>? featured;
  static const frames = [
    ProfileStyleOption('orange', 'PBH', Color(0xFFFF5A1F)),
    ProfileStyleOption('bronze', 'Bronze', Color(0xFFCF9563), minimum: 1),
    ProfileStyleOption('silver', 'Prata', Color(0xFFC7D2E0), minimum: 10),
    ProfileStyleOption('gold', 'Ouro', Color(0xFFFFC45A), minimum: 30),
    ProfileStyleOption(
      'platinum',
      'Platina',
      Color(0xFFE4F4FF),
      badge: 'platinum',
    ),
    ProfileStyleOption(
      'founder',
      'Fundador',
      Color(0xFFFFB547),
      founderOnly: true,
    ),
  ];
  static const covers = [
    ProfileStyleOption('ember', 'Essência PBH', Color(0xFFC84C24)),
    ProfileStyleOption('night', 'Noite', Color(0xFF494B79)),
    ProfileStyleOption('forest', 'Constância', Color(0xFF297D68), minimum: 1),
    ProfileStyleOption('gold', 'Excelência', Color(0xFFAC7B2B), minimum: 30),
    ProfileStyleOption(
      'founder',
      'Legado PBH',
      Color(0xFFCD8B36),
      founderOnly: true,
    ),
  ];
  factory ProfileStyle.fromMetadata(
    Map<String, dynamic> data, {
    bool founder = false,
  }) {
    final raw = data['profile_style'];
    final map = raw is Map ? raw : const {};
    String value(String key, String fallback) =>
        map[key] is String ? map[key] as String : fallback;
    return ProfileStyle(
      frame: value('frame', founder ? 'founder' : 'orange'),
      cover: value('cover', founder ? 'founder' : 'ember'),
      title: value('title', founder ? 'founder' : 'member'),
      featured: map['featured'] is List
          ? (map['featured'] as List)
                .whereType<String>()
                .toSet()
                .take(3)
                .toList()
          : null,
    );
  }
  ProfileStyle copyWith({
    String? frame,
    String? cover,
    String? title,
    List<String>? featured,
  }) => ProfileStyle(
    frame: frame ?? this.frame,
    cover: cover ?? this.cover,
    title: title ?? this.title,
    featured: featured ?? this.featured,
  );
  Map<String, dynamic> toMap() => {
    'frame': frame,
    'cover': cover,
    'title': title,
    if (featured != null) 'featured': featured,
  };
  ProfileStyle validated({
    required bool founder,
    required int completed,
    required List<ProfileAchievement> earned,
  }) {
    final ids = earned.map((e) => e.id).toSet();
    String option(
      List<ProfileStyleOption> options,
      String selected,
      String fallback,
    ) =>
        options.any(
          (o) => o.id == selected && o.available(founder, completed, ids),
        )
        ? selected
        : fallback;
    return ProfileStyle(
      frame: option(frames, frame, 'orange'),
      cover: option(covers, cover, 'ember'),
      title:
          title == 'member' ||
              (title == 'founder' && founder) ||
              ids.contains(title)
          ? title
          : 'member',
      featured: featured?.where(ids.contains).take(3).toList(),
    );
  }

  List<ProfileAchievement> highlights(List<ProfileAchievement> earned) {
    if (featured == null) return earned.take(3).toList();
    final byId = {for (final badge in earned) badge.id: badge};
    return [
      for (final id in featured!.toSet().take(3))
        if (byId[id] != null) byId[id]!,
    ];
  }

  String titleLabel(List<ProfileAchievement> earned) {
    if (title == 'founder') return 'Fundador do PBH';
    for (final badge in earned) {
      if (badge.id == title) return badge.title;
    }
    return 'Membro do PBH';
  }
}
