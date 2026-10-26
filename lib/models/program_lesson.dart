import 'lesson_media.dart';

class ProgramLesson {
  const ProgramLesson({
    required this.id,
    required this.title,
    required this.body,
    required this.practice,
    this.minutes = 3,
    this.habitKey,
    this.media,
  });

  final String id;
  final String title;
  final String body;
  final String practice;
  final int minutes;
  final String? habitKey;
  final LessonMedia? media;

  factory ProgramLesson.fromJson(Map<String, dynamic> json) => ProgramLesson(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    practice: json['practice'] as String,
    minutes: (json['minutes'] as num?)?.toInt() ?? 3,
    habitKey: json['habit_key'] as String?,
    media: json['media'] == null
        ? null
        : LessonMedia.fromJson(Map<String, dynamic>.from(json['media'] as Map)),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'practice': practice,
    'minutes': minutes,
    'habit_key': habitKey,
    if (media != null) 'media': media!.toJson(),
  };
}

class ProgramModule {
  const ProgramModule({
    required this.id,
    required this.title,
    required this.lessons,
  });
  final String id;
  final String title;
  final List<ProgramLesson> lessons;
  factory ProgramModule.fromJson(Map<String, dynamic> json) => ProgramModule(
    id: json['id'] as String,
    title: json['title'] as String,
    lessons: (json['lessons'] as List)
        .map((e) => ProgramLesson.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'lessons': lessons.map((e) => e.toJson()).toList(),
  };
}
