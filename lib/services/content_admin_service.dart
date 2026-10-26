import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program_model.dart';
import 'habit_service.dart';

class ContentAdminService {
  ContentAdminService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  Future<void> _requireAdmin() async {
    if (_client.auth.currentUser == null ||
        await _client.rpc('is_admin') != true) {
      throw StateError('Acesso permitido apenas para administradores.');
    }
  }

  Future<List<Map<String, dynamic>>> list() async {
    await _requireAdmin();
    return await _client
        .from('content_programs')
        .select()
        .order('created_at')
        .timeout(const Duration(seconds: 10));
  }

  static String? validate(ProgramModel program, {required bool published}) {
    if (program.featuredNote.length > 400) {
      return 'A apresentação do destaque pode ter até 400 caracteres.';
    }
    if (program.featuredUntil != null &&
        !program.lessons.any((l) => l.id == program.featuredLessonId)) {
      return 'Escolha uma aula válida para o destaque.';
    }
    if (program.title.trim().isEmpty || program.topic.trim().isEmpty) {
      return 'Preencha o título e o tema.';
    }
    if (program.weeks < 1 || program.weeks > 104) {
      return 'Informe um ritmo entre 1 e 104 semanas.';
    }
    if (published &&
        (program.description.trim().isEmpty ||
            program.tagline.trim().isEmpty ||
            program.outcomes.isEmpty ||
            program.curriculum.isEmpty)) {
      return 'Para publicar, preencha descrição, apresentação, objetivos e ao menos um módulo.';
    }
    final moduleIds = <String>{};
    final lessonIds = <String>{};
    for (final module in program.curriculum) {
      if (module.id.isEmpty ||
          !moduleIds.add(module.id) ||
          module.title.trim().isEmpty) {
        return 'Revise o título e a identificação dos módulos.';
      }
      if (published && module.lessons.isEmpty) {
        return 'Cada módulo publicado precisa ter ao menos uma aula.';
      }
      for (final lesson in module.lessons) {
        if (lesson.media?.validationError != null) {
          return lesson.media!.validationError;
        }
        if (lesson.id.isEmpty || !lessonIds.add(lesson.id)) {
          return 'As aulas precisam de identificações únicas.';
        }
        if (lesson.title.trim().isEmpty ||
            lesson.minutes < 1 ||
            lesson.minutes > 180 ||
            (published &&
                (lesson.body.trim().isEmpty ||
                    lesson.practice.trim().isEmpty))) {
          return 'Preencha título, leitura, prática e duração de cada aula antes de publicar.';
        }
        if (lesson.habitKey != null &&
            !HabitService.habitKeys.contains(lesson.habitKey)) {
          return 'Hábito vinculado inválido.';
        }
      }
    }
    return null;
  }

  Future<void> save(ProgramModel program, {required bool published}) async {
    final error = validate(program, published: published);
    if (error != null) throw ArgumentError(error);
    await _requireAdmin();
    await _client
        .from('content_programs')
        .upsert({
          ...program.toJson(),
          'published': published,
          'featured_until': program.featuredUntil?.toUtc().toIso8601String(),
          'featured_lesson_id': program.featuredLessonId,
          'featured_note': program.featuredNote,
        })
        .timeout(const Duration(seconds: 10));
  }
}
