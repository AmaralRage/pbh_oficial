class CommunityPostModel {
  final String authorName;
  final String authorInitials;
  final String timeAgo;
  final String content;
  final int likes;
  final int comments;
  final String? achievementTag;

  const CommunityPostModel({
    required this.authorName,
    required this.authorInitials,
    required this.timeAgo,
    required this.content,
    required this.likes,
    required this.comments,
    this.achievementTag,
  });
}

const List<CommunityPostModel> mockPosts = [
  CommunityPostModel(
    authorName: 'Marcus V.',
    authorInitials: 'MV',
    timeAgo: '2h',
    content:
        'Dia 30 de disciplina concluído. Não foi sobre motivação, foi sobre decidir uma vez e não negociar todos os dias depois disso.',
    likes: 214,
    comments: 38,
    achievementTag: '30 Dias de Disciplina',
  ),
  CommunityPostModel(
    authorName: 'Rafael T.',
    authorInitials: 'RT',
    timeAgo: '5h',
    content:
        'Comecei o Despertar 5h essa semana. Os três primeiros dias foram os mais difíceis da minha rotina em meses. Hoje já é automático.',
    likes: 132,
    comments: 21,
  ),
  CommunityPostModel(
    authorName: 'Diego M.',
    authorInitials: 'DM',
    timeAgo: '1d',
    content:
        'Alguém mais sentiu diferença real depois de cortar o consumo de conteúdo à toa? Voltei a ler 20 páginas por dia e minha cabeça está mais silenciosa.',
    likes: 89,
    comments: 45,
  ),
  CommunityPostModel(
    authorName: 'Bruno C.',
    authorInitials: 'BC',
    timeAgo: '1d',
    content:
        '60 dias de treino sem faltar um dia sequer. O corpo muda, mas o que mudou mesmo foi minha relação com compromisso.',
    likes: 301,
    comments: 52,
    achievementTag: 'Corpo de Ferro',
  ),
];
