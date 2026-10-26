import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/core/theme/pbh_palette.dart';
import 'package:pbh_oficial/models/lesson_media.dart';
import 'package:pbh_oficial/models/program_lesson.dart';
import 'package:pbh_oficial/models/program_model.dart';
import 'package:pbh_oficial/widgets/lesson_media_card.dart';

void main() {
  const media = LessonMedia(
    title: 'Uma conversa sobre escolhas',
    author: 'Autor',
    summary: 'Uma prévia curta do episódio.',
    url: 'https://www.youtube.com/watch?v=Q083fq9MxQQ',
    audioUrl: 'https://open.spotify.com/episode/7hGWMo7xWxEv0ZtGZRCXeh',
    kind: LessonMediaKind.podcast,
  );
  Widget app(Widget child) => MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [PbhPalette.resolve('pbh')]),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 382, child: child)),
    ),
  );
  test(
    'old lessons load without media and new references survive serialization',
    () {
      final old = ProgramLesson.fromJson({
        'id': 'old',
        'title': 'Aula',
        'body': 'Texto',
        'practice': 'Prática',
      });
      expect(old.media, isNull);
      const lesson = ProgramLesson(
        id: 'new',
        title: 'Aula',
        body: 'Texto',
        practice: 'Prática',
        media: media,
      );
      expect(
        ProgramLesson.fromJson(lesson.toJson()).media!.toJson(),
        media.toJson(),
      );
      expect(
        const LessonMedia(
          title: 't',
          author: 'a',
          summary: 's',
          url: 'javascript:alert(1)',
        ).validationError,
        isNotNull,
      );
    },
  );
  test('related media migration matches the initial curated references', () {
    final sql = File(
      'supabase/migrations/20261026000300_content_related_media.sql',
    ).readAsStringSync();
    final sources =
        jsonDecode(sql.split(r'$media$')[1]) as Map<String, dynamic>;
    for (final id in sources.keys) {
      final p = programCatalog.singleWhere((p) => p.id == id);
      final row = sources[p.id];
      expect(row['lesson_ids'], p.lessons.map((l) => l.id).toList());
      for (final l in p.lessons) {
        expect(l.media, isNotNull);
        expect(l.media!.validationError, isNull);
        expect(row['media'], l.media!.toJson());
      }
    }
  });
  testWidgets('preview opens the selected video or audio link', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      app(
        LessonMediaCard(
          media: media,
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(media.title), findsOneWidget);
    expect(find.text(media.summary), findsOneWidget);
    await tester.ensureVisible(find.text('Assistir episódio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistir episódio'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ouvir podcast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvir podcast'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse(media.url), Uri.parse(media.audioUrl!)]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('opening failure offers a copy link fallback', (tester) async {
    await tester.pumpWidget(
      app(LessonMediaCard(media: media, openLink: (_) async => false)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Assistir episódio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistir episódio'));
    await tester.pumpAndSettle();
    expect(find.text('Copiar link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
