enum LessonMediaKind { video, podcast }

class LessonMedia {
  const LessonMedia({
    required this.title,
    required this.author,
    required this.summary,
    required this.url,
    this.thumbnailUrl,
    this.audioUrl,
    this.kind = LessonMediaKind.video,
  });

  final String title;
  final String author;
  final String summary;
  final String url;
  final String? thumbnailUrl;
  final String? audioUrl;
  final LessonMediaKind kind;

  static bool isWebUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  String? get validationError {
    if (title.trim().isEmpty ||
        author.trim().isEmpty ||
        summary.trim().isEmpty) {
      return 'Preencha título, autor e resumo do vídeo ou podcast.';
    }
    if (!isWebUrl(url) ||
        (thumbnailUrl != null && !isWebUrl(thumbnailUrl!)) ||
        (audioUrl != null && !isWebUrl(audioUrl!))) {
      return 'Use links completos que comecem com https://.';
    }
    return null;
  }

  factory LessonMedia.fromJson(Map<String, dynamic> json) => LessonMedia(
    title: json['title'] as String,
    author: json['author'] as String,
    summary: json['summary'] as String,
    url: json['url'] as String,
    thumbnailUrl: json['thumbnail_url'] as String?,
    audioUrl: json['audio_url'] as String?,
    kind: json['kind'] == 'podcast'
        ? LessonMediaKind.podcast
        : LessonMediaKind.video,
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'summary': summary,
    'url': url,
    'kind': kind.name,
    if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    if (audioUrl != null) 'audio_url': audioUrl,
  };
}
