import 'package:flutter/material.dart';
import 'profile_achievement.dart';
import '../core/theme/pbh_palette.dart';

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
    this.frameEffect = 'orbit',
    this.coverEffect = 'shimmer',
    this.profileTheme = 'app',
  });
  final String frame;
  final String cover;
  final String title;
  final List<String>? featured;
  final String frameEffect;
  final String coverEffect;
  final String profileTheme;
  static const frameEffects = [
    ProfileStyleOption('none', 'Sem animação', Color(0xFF909090)),
    ProfileStyleOption('orbit', 'Órbita de luz', Color(0xFFFFC45A)),
    ProfileStyleOption('pulse', 'Pulso suave', Color(0xFF80DDD5)),
    ProfileStyleOption('sparks', 'Faíscas', Color(0xFFFF8F64)),
    ProfileStyleOption('double', 'Anéis gêmeos', Color(0xFFB7A2FF)),
    ProfileStyleOption(
      'crown',
      'Coroa cósmica',
      Color(0xFF70E8FF),
      founderOnly: true,
    ),
  ];
  static const coverEffects = [
    ProfileStyleOption('none', 'Sem animação', Color(0xFF909090)),
    ProfileStyleOption('shimmer', 'Reflexo de luz', Color(0xFFE4D5FF)),
    ProfileStyleOption('stars', 'Céu estrelado', Color(0xFFBCDFFF)),
    ProfileStyleOption('meteors', 'Estrelas cadentes', Color(0xFFBCDFFF)),
    ProfileStyleOption('aurora', 'Aurora', Color(0xFF71E6CE)),
    ProfileStyleOption('embers', 'Brasas', Color(0xFFFF935D)),
    ProfileStyleOption(
      'legacy',
      'Nebulosa do fundador',
      Color(0xFF70E8FF),
      founderOnly: true,
    ),
  ];
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
      Color(0xFF70E8FF),
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
      Color(0xFF7547CA),
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
      frameEffect: value('frame_effect', founder ? 'crown' : 'orbit'),
      coverEffect: value('cover_effect', founder ? 'legacy' : 'shimmer'),
      profileTheme: value('profile_theme', 'app'),
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
    String? frameEffect,
    String? coverEffect,
    String? profileTheme,
  }) => ProfileStyle(
    frame: frame ?? this.frame,
    cover: cover ?? this.cover,
    title: title ?? this.title,
    featured: featured ?? this.featured,
    frameEffect: frameEffect ?? this.frameEffect,
    coverEffect: coverEffect ?? this.coverEffect,
    profileTheme: profileTheme ?? this.profileTheme,
  );
  Map<String, dynamic> toMap() => {
    'frame': frame,
    'cover': cover,
    'title': title,
    'frame_effect': frameEffect,
    'cover_effect': coverEffect,
    'profile_theme': profileTheme,
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
      frameEffect: option(frameEffects, frameEffect, 'orbit'),
      coverEffect: option(coverEffects, coverEffect, 'shimmer'),
      profileTheme: profileTheme == 'app'
          ? 'app'
          : PbhPalette.resolve(profileTheme, founder: founder).id,
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
