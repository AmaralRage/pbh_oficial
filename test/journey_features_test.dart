import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/lesson_notes_service.dart';
import 'package:pbh_oficial/widgets/lesson_notes_editor.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/services/program_service.dart';
import 'package:pbh_oficial/services/weekly_review_service.dart';
import 'package:pbh_oficial/services/personal_goal_service.dart';
import 'package:pbh_oficial/services/content_admin_service.dart';
import 'package:pbh_oficial/models/program_model.dart';
import 'package:pbh_oficial/models/weekly_review.dart';
import 'package:pbh_oficial/widgets/home_journey_panel.dart';
import 'package:pbh_oficial/widgets/personal_goal_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    client = SupabaseClient('https://test.supabase.co', 'public-key');
  });
  tearDown(() => client.dispose());
  test(
    'notes never migrate silently from a visitor or another account',
    () async {
      var account = 'ad260000-0000-4000-8000-000000000001';
      final jwt =
          'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature';
      final remote = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'access_token': jwt,
              'refresh_token': 'refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': account,
                'aud': 'authenticated',
                'email': 'member@example.com',
                'created_at': '2026-01-01T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(remote.dispose);
      final guest = LessonNotesService(client: remote);
      await guest.save('p', 'l', 'Visitante');
      await remote.auth.signInWithPassword(
        email: 'member@example.com',
        password: 'test',
      );
      final member = LessonNotesService(client: remote);
      expect(await member.load('p', 'l'), '');
      await expectLater(guest.load('p', 'l'), throwsStateError);
      await member.save('p', 'l', 'Primeira conta');
      account = 'ad260000-0000-4000-8000-000000000002';
      await remote.auth.signInWithPassword(
        email: 'other@example.com',
        password: 'test',
      );
      expect(await LessonNotesService(client: remote).load('p', 'l'), '');
      await expectLater(member.load('p', 'l'), throwsStateError);
    },
  );
  test('manual highlights expire and cannot reference a removed lesson', () {
    final now = DateTime.utc(2026, 10, 26);
    final json = programCatalog.first.toJson();
    json['featured_until'] = now.add(const Duration(days: 7)).toIso8601String();
    json['featured_lesson_id'] = programCatalog.first.lessons.first.id;
    final p = ProgramModel.fromJson(json);
    expect(ProgramService.featured([p], now: now)?.id, p.id);
    expect(
      ProgramService.featured([p], now: now.add(const Duration(days: 7))),
      isNull,
    );
    json['featured_lesson_id'] = 'removed';
    expect(
      ContentAdminService.validate(
        ProgramModel.fromJson(json),
        published: true,
      ),
      isNotNull,
    );
  });
  testWidgets(
    'home next step opens the pending routine and shows a weekly comparison',
    (tester) async {
      String? action;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeJourneyPanel(
                pendingHabits: 2,
                activeChallenge: true,
                onHabits: () => action = 'habits',
                onChallenges: () => action = 'challenge',
                onContent: () => action = 'content',
                programService: _Programs(client),
                reviewService: _Review(client),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seu resumo semanal'), findsOneWidget);
      expect(find.text('4 • hábitos registrados'), findsOneWidget);
      await tester.tap(find.text('Registrar os hábitos de hoje'));
      await tester.pumpAndSettle();
      expect(action, 'habits');
    },
  );
  testWidgets('new personal goals are private unless the owner opts in', (
    tester,
  ) async {
    final service = _Goals(client);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PersonalGoalCard(isAuthenticated: true, service: service),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Definir objetivo'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Ler com constância',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar objetivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar objetivo'));
    await tester.pumpAndSettle();
    expect(service.goal?['is_public'], isFalse);
    expect(find.text('Objetivo privado'), findsOneWidget);
  });
  test(
    'community filters the selected topic and includes categorized achievements',
    () async {
      Uri? requested;
      final remote = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(remote.dispose);
      await CommunityService(
        client: remote,
      ).fetchPosts(filterIndex: 2, topic: 'conquistas');
      expect(requested!.queryParameters['topic'], 'eq.conquistas');
      expect(requested!.queryParameters['or'], contains('topic.eq.conquistas'));
    },
  );
  test(
    'notes survive recreation and remain separate for each lesson',
    () async {
      final service = LessonNotesService(client: client);
      await service.save('program', 'lesson', 'Uma reflexão privada');
      final restored = LessonNotesService(client: client);
      expect(await restored.load('program', 'lesson'), 'Uma reflexão privada');
      expect(await restored.load('program', 'another'), '');
      await restored.save('program', 'lesson', '');
      expect(await service.load('program', 'lesson'), '');
    },
  );
  testWidgets('notes save and require a decision before discarding edits', (
    tester,
  ) async {
    final service = LessonNotesService(client: client);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(),
                    body: SingleChildScrollView(
                      child: LessonNotesEditor(
                        programId: 'p',
                        lessonId: 'l',
                        service: service,
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Primeira anotação');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar anotação'));
    await tester.pumpAndSettle();
    expect(await service.load('p', 'l'), 'Primeira anotação');
    await tester.enterText(find.byType(TextField), 'Alteração ainda não salva');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Salvar sua anotação?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    expect(await service.load('p', 'l'), 'Primeira anotação');
  });
}

class _Programs extends ProgramService {
  _Programs(SupabaseClient client) : super(client: client);
  @override
  Future<List<ProgramModel>> availableCatalog() async => programCatalog;
  @override
  Future<Map<String, ProgramProgress>> loadAll(
    List<ProgramModel> programs,
  ) async => {};
}

class _Review extends WeeklyReviewService {
  _Review(SupabaseClient client) : super(client: client);
  @override
  Future<WeeklyReview> load(
    Iterable<ProgramProgress>? progress, {
    DateTime? now,
  }) async => WeeklyReview(
    start: DateTime(2026, 10, 26),
    today: DateTime(2026, 10, 28),
    habits: 4,
    previousHabits: 2,
    lessons: 1,
    previousLessons: 0,
    challengeDays: 2,
    previousChallengeDays: 1,
  );
}

class _Goals extends PersonalGoalService {
  _Goals(SupabaseClient client) : super(client: client);
  Map<String, dynamic>? goal;
  @override
  Future<Map<String, dynamic>?> load() async => goal;
  @override
  Future<List<Map<String, dynamic>>> entries() async => [];
  @override
  Future<void> save(String title, String nextStep, bool isPublic) async {
    goal = {'title': title, 'next_step': nextStep, 'is_public': isPublic};
  }
}
