class CommunityPostModel {
  final String authorName;
  final String authorInitials;
  final String timeAgo;
  final String content;
  final int likes;
  final int comments;
  final String? achievementTag;
  final String? avatarAsset;
  final bool isJapanese;

  const CommunityPostModel({
    required this.authorName,
    required this.authorInitials,
    required this.timeAgo,
    required this.content,
    required this.likes,
    required this.comments,
    this.achievementTag,
    this.avatarAsset,
    this.isJapanese = false,
  });
}

const List<CommunityPostModel> mockPosts = [
  CommunityPostModel(
    authorName: 'Samuel Robson Fiales',
    authorInitials: 'SR',
    timeAgo: '18min',
    content:
        'Entrei buscando disciplina e encontrei uma nova forma de conduzir minha vida. A rotina me devolveu presença em casa, foco no trabalho e confiança para cumprir o que prometo.',
    likes: 187,
    comments: 29,
    achievementTag: 'Jornada transformadora',
    avatarAsset: 'assets/images/samuel.png',
  ),
  CommunityPostModel(
    authorName: 'Wellerson Ramos',
    authorInitials: 'WR',
    timeAgo: '42min',
    content:
        'Depois de participar do projeto, parei de esperar motivação para agir. Os pequenos compromissos diários mudaram minha saúde, minha família e a maneira como enxergo meu futuro.',
    likes: 163,
    comments: 24,
    avatarAsset: 'assets/images/wellerson.png',
  ),
  CommunityPostModel(
    authorName: 'Chad',
    authorInitials: 'CH',
    timeAgo: '1h',
    content:
        'A comunidade me mostrou que evolução não precisa ser solitária. Hoje tenho constância, apoio e orgulho da pessoa que estou construindo todos os dias.',
    likes: 121,
    comments: 18,
    avatarAsset: 'assets/images/chad.png',
  ),
  CommunityPostModel(
    authorName: 'Kanye West',
    authorInitials: 'KW',
    timeAgo: '2h',
    content:
        'Dia 30 de disciplina concluído. Não foi sobre motivação, foi sobre decidir uma vez e não negociar todos os dias depois disso.',
    likes: 214,
    comments: 38,
    achievementTag: '30 Dias de Disciplina',
    avatarAsset: 'assets/images/kanye.png',
  ),
  CommunityPostModel(
    authorName: 'Miyazaki',
    authorInitials: 'MI',
    timeAgo: '1時間前',
    content:
        'このプロジェクトに参加してから、毎日の小さな習慣が自分を変える力になると実感しました。規律を守ることで、心も生活も以前より強くなりました。',
    likes: 132,
    comments: 21,
    avatarAsset: 'assets/images/miyazaki.png',
    isJapanese: true,
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
