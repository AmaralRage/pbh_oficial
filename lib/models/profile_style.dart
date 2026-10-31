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
    this.requiredBadges = const [],
    this.founderOnly = false,
    this.hiddenUnlessAvailable = false,
  });
  final String id;
  final String label;
  final Color color;
  final int minimum;
  final String? badge;
  final List<String> requiredBadges;
  final bool founderOnly;
  final bool hiddenUnlessAvailable;
  bool visible(bool founder, int completed, Set<String> earned) =>
      !hiddenUnlessAvailable || available(founder, completed, earned);
  bool available(bool founder, int completed, Set<String> earned) => founderOnly
      ? founder
      : (founder ||
            (completed >= minimum &&
                (badge == null || earned.contains(badge)) &&
                requiredBadges.every(earned.contains)));
  String get requirement => founderOnly
      ? 'Exclusivo do fundador'
      : badge == 'supreme_crown'
      ? 'Concedida pessoalmente pelo fundador'
      : requiredBadges.isNotEmpty
      ? 'Conquiste a Platina PBH e o Rubi do Conhecimento'
      : badge == 'knowledge_platinum'
      ? 'Conquiste o Rubi do Conhecimento'
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
    this.frameIntensity = .5,
    this.coverIntensity = .5,
    this.coverVariant = 'royal',
    this.background = 'none',
    this.backgroundPath = '',
    this.backgroundDim = .35,
  });
  final String frame;
  final String cover;
  final String title;
  final List<String>? featured;
  final String frameEffect;
  final String coverEffect;
  final String profileTheme;
  final double frameIntensity;
  final double coverIntensity;
  final String coverVariant;
  final String background;
  final String backgroundPath;
  final double backgroundDim;
  static const backgrounds = [
    ProfileStyleOption('none', 'Padrão', Color(0xFF242424)),
    ProfileStyleOption('ember', 'Essência PBH', Color(0xFFFF813D)),
    ProfileStyleOption('library', 'Biblioteca', Color(0xFFB68A55)),
    ProfileStyleOption('astral', 'Astral', Color(0xFF9D80FF)),
    ProfileStyleOption('custom', 'Minha imagem', Color(0xFF6CCFD8)),
  ];
  static String safeBackground(Object? value) =>
      backgrounds.any((o) => o.id == value) ? value as String : 'none';
  static double safeBackgroundDim(Object? value) =>
      value is num && value.isFinite ? value.toDouble().clamp(0, .85) : .35;
  static String safeBackgroundPath(Object? value) =>
      value is String &&
          RegExp(
            r'^[0-9a-fA-F-]{36}/[0-9]+\.(jpeg|jpg|png|webp)$',
          ).hasMatch(value)
      ? value
      : '';
  static const nebulaVariants = [
    ProfileStyleOption(
      'royal',
      'Nebulosa Imperial',
      Color(0xFFB779FF),
      founderOnly: true,
    ),
    ProfileStyleOption(
      'astral',
      'Energia Astral',
      Color(0xFF1EF5F2),
      founderOnly: true,
    ),
    ProfileStyleOption(
      'eclipse',
      'Eclipse Cósmico',
      Color(0xFFFF9B45),
      founderOnly: true,
    ),
  ];
  static String safeCoverVariant(Object? value) =>
      nebulaVariants.any((o) => o.id == value) ? value as String : 'royal';
  static const weatherEffects = {'rain', 'snow', 'fireflies'};
  static const seasonalEffects = {'halloween', 'christmas', 'new_year'};
  static const platinumEffects = {
    'platinum_orbit',
    'platinum_iron',
    'knowledge_orbit',
    'journey_crown',
    'platinum_ascent',
    'platinum_throne',
    'knowledge_constellation',
    'journey_legacy',
  };
  static const legendaryFrameEffects = {
    'platinum_orbit',
    'knowledge_orbit',
    'journey_crown',
    'platinum_iron',
  };
  static const decoratedFrameEffects = {
    'supreme_crown',
    'crown',
    ...legendaryFrameEffects,
    ...eventFrameEffects,
    'orbit',
    'pulse',
    'sparks',
    'double',
  };
  static const eventFrameEffects = {
    'rain',
    'halloween',
    'christmas',
    'new_year',
  };
  static bool hasIntensity(String effect) =>
      effect != 'none' &&
      [...frameEffects, ...coverEffects].any((option) => option.id == effect);
  static double safeIntensity(Object? value) =>
      value is num && value.isFinite ? value.toDouble().clamp(0, 1) : .5;
  static const frameEffects = [
    ProfileStyleOption(
      'supreme_crown',
      'Coroa Suprema',
      Color(0xFFDAAEFF),
      badge: 'supreme_crown',
      hiddenUnlessAvailable: true,
    ),
    ProfileStyleOption('none', 'Sem animação', Color(0xFF909090)),
    ProfileStyleOption('orbit', 'Órbita de luz', Color(0xFFA5C7FF)),
    ProfileStyleOption('pulse', 'Pulso suave', Color(0xFFBCA5FF)),
    ProfileStyleOption('sparks', 'Chamas Vivas', Color(0xFFFF8F35)),
    ProfileStyleOption('double', 'Anéis gêmeos', Color(0xFFB7A2FF)),
    ProfileStyleOption(
      'platinum_orbit',
      'Guardião de Platina',
      Color(0xFFB6EAFF),
      badge: 'platinum',
    ),
    ProfileStyleOption(
      'platinum_iron',
      'Juramento de Ferro',
      Color(0xFFFF8A45),
      badge: 'platinum',
    ),
    ProfileStyleOption(
      'knowledge_orbit',
      'Selo Arcano',
      Color(0xFFA7A1FF),
      badge: 'knowledge_platinum',
    ),
    ProfileStyleOption(
      'journey_crown',
      'Coroa do Legado',
      Color(0xFFFFD38A),
      requiredBadges: ['platinum', 'knowledge_platinum'],
    ),
    ProfileStyleOption('rain', 'Chuva', Color(0xFF83CFFF)),
    ProfileStyleOption('snow', 'Neve', Color(0xFFE0F4FF)),
    ProfileStyleOption('fireflies', 'Vaga-lumes', Color(0xFFBBF878)),
    ProfileStyleOption('halloween', 'Halloween', Color(0xFFFFA24C)),
    ProfileStyleOption('christmas', 'Natal', Color(0xFF85E5A2)),
    ProfileStyleOption('new_year', 'Ano Novo', Color(0xFFFFD878)),
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
    ProfileStyleOption(
      'platinum_ascent',
      'Forja da Disciplina',
      Color(0xFFFF9B35),
      badge: 'platinum',
    ),
    ProfileStyleOption(
      'platinum_throne',
      'Trono do Inabalável',
      Color(0xFFB779FF),
      badge: 'platinum',
    ),
    ProfileStyleOption(
      'knowledge_constellation',
      'Biblioteca dos Sábios',
      Color(0xFFFFD78B),
      badge: 'knowledge_platinum',
    ),
    ProfileStyleOption(
      'journey_legacy',
      'Observatório Eterno',
      Color(0xFFB2D8FF),
      requiredBadges: ['platinum', 'knowledge_platinum'],
    ),
    ProfileStyleOption('embers', 'Brasas', Color(0xFFFF935D)),
    ProfileStyleOption('rain', 'Chuva', Color(0xFF83CFFF)),
    ProfileStyleOption('snow', 'Neve', Color(0xFFE0F4FF)),
    ProfileStyleOption('fireflies', 'Vaga-lumes', Color(0xFFBBF878)),
    ProfileStyleOption('halloween', 'Halloween', Color(0xFFFFA24C)),
    ProfileStyleOption('christmas', 'Natal', Color(0xFF85E5A2)),
    ProfileStyleOption('new_year', 'Ano Novo', Color(0xFFFFD878)),
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
    ProfileStyleOption('bonfire', 'Fogueira das Almas', Color(0xFFFF872F)),
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
      background: safeBackground(map['background']),
      backgroundPath: safeBackgroundPath(map['background_path']),
      backgroundDim: safeBackgroundDim(map['background_dim']),
      frame: value('frame', founder ? 'founder' : 'orange'),
      cover: value('cover', founder ? 'founder' : 'ember'),
      title: value('title', founder ? 'founder' : 'member'),
      frameEffect: value('frame_effect', founder ? 'crown' : 'orbit'),
      coverEffect: value('cover_effect', founder ? 'legacy' : 'shimmer'),
      profileTheme: value('profile_theme', 'app'),
      frameIntensity: safeIntensity(map['frame_intensity']),
      coverIntensity: safeIntensity(map['cover_intensity']),
      coverVariant: safeCoverVariant(map['cover_variant']),
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
    String? background,
    String? backgroundPath,
    double? backgroundDim,
    String? frame,
    String? cover,
    String? title,
    List<String>? featured,
    String? frameEffect,
    String? coverEffect,
    String? profileTheme,
    double? frameIntensity,
    double? coverIntensity,
    String? coverVariant,
  }) => ProfileStyle(
    background: safeBackground(background ?? this.background),
    backgroundPath: safeBackgroundPath(backgroundPath ?? this.backgroundPath),
    backgroundDim: safeBackgroundDim(backgroundDim ?? this.backgroundDim),
    frame: frame ?? this.frame,
    cover: cover ?? this.cover,
    title: title ?? this.title,
    featured: featured ?? this.featured,
    frameEffect: frameEffect ?? this.frameEffect,
    coverEffect: coverEffect ?? this.coverEffect,
    profileTheme: profileTheme ?? this.profileTheme,
    frameIntensity: safeIntensity(frameIntensity ?? this.frameIntensity),
    coverIntensity: safeIntensity(coverIntensity ?? this.coverIntensity),
    coverVariant: safeCoverVariant(coverVariant ?? this.coverVariant),
  );
  Map<String, dynamic> toMap() => {
    'background': safeBackground(background),
    'background_path': safeBackgroundPath(backgroundPath),
    'background_dim': safeBackgroundDim(backgroundDim),
    'frame': frame,
    'cover': cover,
    'title': title,
    'frame_effect': frameEffect,
    'cover_effect': coverEffect,
    'profile_theme': profileTheme,
    'frame_intensity': safeIntensity(frameIntensity),
    'cover_intensity': safeIntensity(coverIntensity),
    'cover_variant': safeCoverVariant(coverVariant),
    if (featured != null) 'featured': featured,
  };
  ProfileStyle validated({
    required bool founder,
    required int completed,
    required List<ProfileAchievement> earned,
    Set<String> manualAwards = const {},
  }) {
    final ids = earned.map((e) => e.id).toSet();
    String option(
      List<ProfileStyleOption> options,
      String selected,
      String fallback,
    ) =>
        options.any(
          (o) =>
              o.id == selected &&
              o.available(founder, completed, {...ids, ...manualAwards}),
        )
        ? selected
        : fallback;
    return ProfileStyle(
      background: safeBackground(background),
      backgroundPath: safeBackgroundPath(backgroundPath),
      backgroundDim: safeBackgroundDim(backgroundDim),
      frame: option(frames, frame, 'orange'),
      cover: option(covers, cover, 'ember'),
      frameEffect: option(frameEffects, frameEffect, 'orbit'),
      coverEffect: option(coverEffects, coverEffect, 'shimmer'),
      frameIntensity: safeIntensity(frameIntensity),
      coverIntensity: safeIntensity(coverIntensity),
      coverVariant: founder ? safeCoverVariant(coverVariant) : 'royal',
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

  List<ProfileAchievement> profileMiniatures(List<ProfileAchievement> earned) {
    final fixed = [
      for (final id in ['platinum', 'knowledge_platinum'])
        for (final badge in earned)
          if (badge.id == id) badge,
    ];
    final extras = earned.where((badge) => !badge.isJourneyTrophy).toList();
    return [...fixed, ...highlights(extras)];
  }

  String titleLabel(List<ProfileAchievement> earned) {
    if (title == 'founder') return 'Fundador do PBH';
    for (final badge in earned) {
      if (badge.id == title) return badge.title;
    }
    return 'Membro do PBH';
  }
}
