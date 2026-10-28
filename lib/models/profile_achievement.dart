import 'package:flutter/material.dart';
import 'challenge_journey.dart';

class ProfileAchievement {
  const ProfileAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.color = const Color(0xFFFF5A1F),
    this.artAsset,
    this.htmlAsset,
    this.category,
    this.artCaption,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? artAsset;
  final String? htmlAsset;
  final String? category;
  final String? artCaption;
  String get kindLabel => id.startsWith('supreme_')
      ? 'SELO CONCEDIDO'
      : id == 'streak'
      ? 'SELO DE DEDICAÇÃO'
      : id == 'community'
      ? 'MARCO DA COMUNIDADE'
      : 'CONQUISTA DE DESAFIOS';
  String get requirement => id.startsWith('supreme_')
      ? 'Selo concedido pelo fundador ou reservado à identidade do fundador. Não é liberado apenas pela duração de um desafio.'
      : id == 'platinum'
      ? 'Concluir todos os desafios da Jornada Original PBH (57 desafios).'
      : id == 'knowledge_platinum'
      ? 'Concluir os cinco desafios da Jornada do Conhecimento.'
      : id == 'streak'
      ? 'Manter a sequência de dedicação indicada no selo.'
      : id == 'challenges'
      ? 'Concluir a quantidade de desafios indicada no título.'
      : id == 'community'
      ? 'Ter a quantidade de pessoas acompanhando sua jornada indicada no título.'
      : 'Concluir o desafio correspondente a este selo.';

  static const challenges50 = ProfileAchievement(
    id: 'challenges',
    title: '50 desafios concluídos',
    description:
        'Você conquistou 50 troféus de desafios. Um marco de disciplina e dedicação ao PBH.',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFF66EFC9),
    artAsset: 'assets/images/trofeu_50_desafios.png',
    htmlAsset: 'assets/images/Trofeu_50_desafios_concluidos.html',
    category: 'DESAFIOS',
    artCaption: '50 DESAFIOS • DEDICAÇÃO AO PBH',
  );

  static const dedication2000 = ProfileAchievement(
    id: 'streak',
    title: '2000 dias de dedicação',
    description:
        'Um marco de 2000 dias de dedicação ao PBH. Uma conquista extraordinária de constância, disciplina e superação.',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF4B34C),
    artAsset: 'assets/images/trofeu_2000_dias.png',
    htmlAsset: 'assets/images/Trofeu_2000_completo.html',
    category: 'CONSTÂNCIA',
    artCaption: '2000 DIAS • DEDICAÇÃO AO PBH',
  );

  static const platinum = ProfileAchievement(
    id: 'platinum',
    title: 'Platina PBH',
    description:
        'Todos os 57 desafios da Jornada Original PBH foram conquistados. Um símbolo de dedicação, excelência e superação no PBH.',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFE4F4FF),
    artAsset: 'assets/images/trofeu_platina_pbh.png',
    htmlAsset: 'assets/images/Trofeu_Platina_PBH.html',
    category: 'PLATINA',
  );

  static const knowledgePlatinum = ProfileAchievement(
    id: 'knowledge_platinum',
    title: 'Mente desperta',
    description:
        'Você concluiu os cinco desafios da Jornada do Conhecimento: leitura, anotações, estudo, explicação e aplicação. Sua platina celebra o conhecimento colocado em prática.',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFE4F4FF),
    artAsset: 'assets/images/trofeu_platina_pbh.png',
    htmlAsset: 'assets/images/Trofeu_Platina_PBH.html',
    artCaption: 'JORNADA DO CONHECIMENTO • PLATINA PBH',
    category: 'CONHECIMENTO',
  );

  static const supremeSeals = [
    ProfileAchievement(
      id: 'supreme_meditation',
      title: 'Ascensão suprema',
      description:
          'Troféu supremo de meditação. Um selo de dedicação à calma, à presença e à evolução interior.',
      icon: Icons.self_improvement_rounded,
      color: Color(0xFFC58CFF),
      artAsset: 'assets/images/trofeu_supremo_meditacao.png',
      htmlAsset: 'assets/images/Troféu supremo PBH.html',
      category: 'MEDITAÇÃO',
    ),
    ProfileAchievement(
      id: 'supreme_training',
      title: 'Força suprema',
      description:
          'Troféu supremo de treino. A força é construída a cada compromisso cumprido. A disciplina agora é parte de você.',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFFF7050),
      artAsset: 'assets/images/trofeu_supremo_treino.png',
      htmlAsset: 'assets/images/Troféu supremo de treino.html',
      category: 'TREINO',
    ),
    ProfileAchievement(
      id: 'supreme_reading',
      title: 'Sabedoria suprema',
      description:
          'Troféu supremo de leitura. Cada página transforma a sua jornada. O conhecimento agora é parte de você.',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFF6CEBD5),
      artAsset: 'assets/images/trofeu_supremo_leitura.png',
      htmlAsset: 'assets/images/Troféu supremo de leitura.html',
      category: 'LEITURA',
    ),
    ProfileAchievement(
      id: 'supreme_porn_free',
      title: 'Mente limpa',
      description:
          'Troféu supremo do desafio sem pornô. Um selo de dedicação às suas escolhas, ao foco e à liberdade pessoal.',
      icon: Icons.shield_outlined,
      color: Color(0xFF76CFFF),
      artAsset: 'assets/images/trofeu_supremo_sem_porno.png',
      htmlAsset: 'assets/images/Troféu supremo sem pornô.html',
      category: 'SEM PORNÔ',
    ),
  ];

  static List<ProfileAchievement> earned({
    required bool isAuthenticated,
    required bool isProjectLeader,
    required int streak,
    required int completedChallenges,
    required int totalChallenges,
    required int followers,
    required Set<String> completedIds,
    Set<String> manualAwards = const {},
  }) {
    if (!isAuthenticated) return const [];
    final badges = <ProfileAchievement>[];
    for (final seal in supremeSeals) {
      if (isProjectLeader || manualAwards.contains(seal.id)) badges.add(seal);
    }
    if (ChallengeJourney.original.unlocked(completedIds) ||
        (totalChallenges == 57 && completedChallenges == 57)) {
      badges.add(platinum);
    }
    if (ChallengeJourney.knowledge.unlocked(completedIds))
      badges.add(knowledgePlatinum);
    for (final days in [
      5000,
      3650,
      3000,
      2500,
      2000,
      1825,
      1500,
      1200,
      1000,
      900,
      730,
      600,
      500,
      400,
      365,
      300,
      250,
      200,
      180,
      150,
      120,
      100,
      90,
      75,
      60,
      45,
      30,
      21,
      14,
      7,
    ]) {
      if (streak < days) continue;
      if (days == 2000) {
        badges.add(dedication2000);
        break;
      }
      badges.add(
        ProfileAchievement(
          id: 'streak',
          title: '$days dias de dedicação',
          description: isProjectLeader
              ? 'Um marco de $days dias na história do líder e criador do PBH Oficial.'
              : 'Uma sequência de $days dias de compromisso com a sua rotina. A constância constrói a evolução.',
          icon: Icons.local_fire_department_rounded,
        ),
      );
      break;
    }
    for (final count in [50, 30, 20, 10, 5, 3, 1]) {
      if (completedChallenges < count) continue;
      if (count == 50) {
        badges.add(challenges50);
        break;
      }
      badges.add(
        ProfileAchievement(
          id: 'challenges',
          title:
              '$count ${count == 1 ? 'desafio concluído' : 'desafios concluídos'}',
          description:
              'Você conquistou $count ${count == 1 ? 'troféu de desafio' : 'troféus de desafios'}. Cada compromisso cumprido faz parte da sua história no PBH.',
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFFFB547),
        ),
      );
      break;
    }
    const special = <String, ProfileAchievement>{
      'digital_fast': ProfileAchievement(
        id: 'digital_fast',
        title: 'Foco inabalável',
        description:
            'Desafio de jejum digital concluído. Você escolheu presença e foco para cuidar da sua atenção.',
        icon: Icons.self_improvement_rounded,
        color: Color(0xFFBC8AFF),
        artAsset: 'assets/images/trofeu_foco_inabalavel.png',
        htmlAsset:
            'assets/images/Trofeu_foco_inabalavel_ametista_PBH_universo.html',
        category: 'FOCO',
        artCaption: 'FOCO INABALÁVEL • DESAFIO CONCLUÍDO',
      ),
      'iron_body': ProfileAchievement(
        id: 'iron_body',
        title: 'Corpo de ferro',
        description:
            'Desafio Corpo de Ferro concluído. Um selo de disciplina e compromisso com o movimento.',
        icon: Icons.fitness_center_rounded,
        color: Color(0xFFFF6D79),
        artAsset: 'assets/images/trofeu_corpo_de_ferro.png',
        htmlAsset:
            'assets/images/Trofeu_corpo_de_ferro_PBH_pulso_reforcado.html',
        category: 'TREINO',
        artCaption: 'CORPO DE FERRO • DESAFIO CONCLUÍDO',
      ),
      'daily_reading': ProfileAchievement(
        id: 'daily_reading',
        title: 'Leitor assíduo',
        description:
            'Desafio de leitura diária concluído. Conhecimento cultivado uma página de cada vez.',
        icon: Icons.menu_book_rounded,
        color: Color(0xFF62EAC7),
        artAsset: 'assets/images/trofeu_leitor_assiduo.png',
        htmlAsset: 'assets/images/Trofeu_leitor_assiduo_esmeralda_PBH.html',
        category: 'LEITURA',
        artCaption: 'LEITOR ASSÍDUO • DESAFIO CONCLUÍDO',
      ),
      'wake_5': ProfileAchievement(
        id: 'wake_5',
        title: 'Madrugador',
        description:
            'Desafio de acordar cedo concluído. Você criou espaço para começar o dia com intenção.',
        icon: Icons.wb_twilight_rounded,
        color: Color(0xFFF7A1CD),
        artAsset: 'assets/images/trofeu_madrugador.png',
        htmlAsset: 'assets/images/Trofeu_madrugador_rosa_perola_mar_PBH.html',
        category: 'ROTINA',
        artCaption: 'MADRUGADOR • DESAFIO CONCLUÍDO',
      ),
    };
    for (final entry in special.entries) {
      if (completedIds.contains(entry.key)) badges.add(entry.value);
    }
    for (final count in [50, 25, 10, 5, 1]) {
      if (followers < count) continue;
      badges.add(
        ProfileAchievement(
          id: 'community',
          title: 'Inspira $count ${count == 1 ? 'pessoa' : 'pessoas'}',
          description:
              '$count ${count == 1 ? 'pessoa acompanha' : 'pessoas acompanham'} sua jornada. Sua dedicação também inspira a comunidade.',
          icon: Icons.groups_rounded,
        ),
      );
      break;
    }
    return badges;
  }
}
