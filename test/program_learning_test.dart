import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/program_model.dart';
import 'package:pbh_oficial/services/program_service.dart';
import 'package:pbh_oficial/models/weekly_review.dart';
import 'package:pbh_oficial/services/content_admin_service.dart';
import 'package:pbh_oficial/screens/program_detail_screen.dart';
import 'package:pbh_oficial/screens/content_screen.dart';
import 'package:pbh_oficial/screens/admin_content_screen.dart';
import 'package:pbh_oficial/core/theme/pbh_palette.dart';

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
    'weekly review excludes undated completions and compares calendar weeks',
    () {
      final now = DateTime(2026, 11, 1);
      expect(WeeklyReview.monday(now), DateTime(2026, 10, 26));
      final state = ProgramProgress(
        completed: {'old', 'this', 'previous'},
        completedAt: {
          'this': DateTime(2026, 10, 30, 12).toUtc().toIso8601String(),
          'previous': DateTime(2026, 10, 23, 12).toUtc().toIso8601String(),
          'not_completed': DateTime(2026, 10, 30, 12).toUtc().toIso8601String(),
        },
      );
      expect(
        WeeklyReview.datedLessons([state], DateTime(2026, 10, 26), now),
        1,
      );
      expect(
        WeeklyReview.datedLessons(
          [state],
          DateTime(2026, 10, 19),
          DateTime(2026, 10, 25),
        ),
        1,
      );
    },
  );
  test('all programs contain real lessons with stable unique identifiers', () {
    for (final p in programCatalog) {
      expect(ContentAdminService.validate(p, published: true), isNull);
      expect(p.modules, p.curriculum.length);
      expect(p.lessons, isNotEmpty);
      expect(p.lessons.map((l) => l.id).toSet().length, p.lessons.length);
      for (final l in p.lessons) {
        expect(l.body.trim(), isNotEmpty);
        expect(l.practice.trim(), isNotEmpty);
      }
      expect(
        ProgramModel.fromJson(p.toJson()).lessons.length,
        p.lessons.length,
      );
    }
  });
  test('initial SQL catalog preserves the original four programs', () {
    final sql = File(
      'supabase/migrations/20261026000200_content_initial_catalog.sql',
    ).readAsStringSync();
    final data = sql.split(r'$catalog$')[1];
    final rows = jsonDecode(data) as List;
    expect(rows.length, 4);
    for (final row in rows) {
      final p = programCatalog.singleWhere((p) => p.id == row['id']);
      final initial = p.toJson();
      // A mídia foi acrescentada em uma migration posterior ao catálogo inicial.
      for (final module in initial['curriculum'] as List) {
        for (final lesson in module['lessons'] as List) {
          lesson.remove('media');
        }
      }
      expect(rows.firstWhere((r) => r['id'] == p.id), {
        ...initial,
        'published': true,
      });
    }
  });
  test('nihilism migration matches the published program and its video', () {
    final sql = File(
      'supabase/migrations/20261026000400_content_nihilism.sql',
    ).readAsStringSync();
    final rows = jsonDecode(sql.split(r'$nihilism$')[1]) as List;
    final program = programCatalog.singleWhere(
      (p) => p.id == 'niilismo_sentido',
    );
    expect(rows.single, {...program.toJson(), 'published': true});
    expect(
      program.lessons.every(
        (l) => l.media?.validationError == null && l.media != null,
      ),
      isTrue,
    );
  });
  test(
    'publication refuses incomplete curriculum and duplicate lesson IDs',
    () {
      final json = programCatalog.first.toJson();
      expect(
        ContentAdminService.validate(
          ProgramModel.fromJson(json),
          published: true,
        ),
        isNull,
      );
      json['curriculum'] = [];
      expect(
        ContentAdminService.validate(
          ProgramModel.fromJson(json),
          published: true,
        ),
        isNotNull,
      );
      expect(
        ContentAdminService.validate(
          ProgramModel.fromJson(json),
          published: false,
        ),
        isNull,
      );
      final duplicate = programCatalog.first.toJson();
      final modules = duplicate['curriculum'] as List;
      final lessons = modules.first['lessons'] as List;
      lessons.add(lessons.first);
      expect(
        ContentAdminService.validate(
          ProgramModel.fromJson(duplicate),
          published: true,
        ),
        isNotNull,
      );
    },
  );
  test('concurrent services preserve all locally completed lessons', () async {
    final p = programCatalog.first;
    await Future.wait([
      ProgramService(
        client: client,
      ).update(p.id, completedLesson: p.lessons[0].id),
      ProgramService(
        client: client,
      ).update(p.id, completedLesson: p.lessons[1].id),
    ]);
    expect(
      (await ProgramService(client: client).read(p.id)).completedCount(p),
      2,
    );
  });
  test('an empty remote catalog stays empty; drafts are not public', () async {
    var rows = <Map<String, dynamic>>[];
    final remote = SupabaseClient(
      'https://test.supabase.co',
      'public-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(remote.dispose);
    final service = ProgramService(client: remote);
    expect(await service.availableCatalog(), isEmpty);
    rows = [
      {...programCatalog.first.toJson(), 'published': false},
    ];
    expect(await service.availableCatalog(), isEmpty);
    rows = [
      {...programCatalog.first.toJson(), 'published': true},
    ];
    expect(
      (await service.availableCatalog()).single.id,
      programCatalog.first.id,
    );
  });
  testWidgets(
    'catalog can search lesson titles and resume the next lesson on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _LocalProgramService(client);
      final p = programCatalog.first;
      await service.update(p.id, completedLesson: p.lessons.first.id);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [PbhPalette.resolve('pbh')],
          ),
          home: Scaffold(body: ContentScreen(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue de onde parou'), findsOneWidget);
      await tester.ensureVisible(find.text('Continuar aula'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar aula'));
      await tester.pumpAndSettle();
      expect(find.text(p.lessons[1].title), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Separe fatos');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1 programas encontrados'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 programas encontrados'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'admin edits and saves a program with stable lesson identifiers',
    (tester) async {
      final service = _MemoryAdminService(client);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [PbhPalette.resolve('pbh')],
          ),
          home: AdminContentScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(programCatalog.first.title));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Fundamentos revisados',
      );
      await tester.scrollUntilVisible(
        find.text('Salvar programa'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar programa'));
      await tester.pumpAndSettle();
      expect(service.saved?.title, 'Fundamentos revisados');
      expect(
        service.saved?.lessons.first.id,
        programCatalog.first.lessons.first.id,
      );
      expect(find.text('Gerenciar conteúdo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('offline progress replays and merges; accounts remain isolated', () async {
    var online = false;
    var account = '00000000-0000-0000-0000-000000000001';
    var rpcCalls = 0;
    final p = programCatalog.first;
    Map<String, dynamic> remote = {
      'program_id': p.id,
      'saved': false,
      'started': true,
      'completed': [p.lessons[1].id],
    };
    final jwt =
        'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature';
    final authenticated = SupabaseClient(
      'https://test.supabase.co',
      'public-key',
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/auth/')) {
          return http.Response(
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
          );
        }
        if (!online) throw http.ClientException('offline');
        if (request.url.path.contains('/rpc/')) {
          rpcCalls++;
          final params = jsonDecode(request.body) as Map<String, dynamic>;
          remote = {
            'program_id': p.id,
            'saved': params['p_saved'],
            'started': params['p_started'],
            'saved_at': params['p_saved_at'],
            'opened_at': params['p_opened_at'],
            'completed_at': {
              ...Map<String, dynamic>.from(
                remote['completed_at'] as Map? ?? {},
              ),
              ...Map<String, dynamic>.from(
                params['p_completed_at'] as Map? ?? {},
              ),
            },
            'completed': {
              ...List<String>.from(remote['completed'] as List),
              ...List<String>.from(params['p_completed'] as List),
            }.toList(),
          };
          return http.Response(
            jsonEncode(remote),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode([remote]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(authenticated.dispose);
    await authenticated.auth.signInWithPassword(
      email: 'member@example.com',
      password: 'test',
    );
    final service = ProgramService(client: authenticated);
    await service.update(
      p.id,
      completedLesson: p.lessons.first.id,
      saved: true,
    );
    expect((await service.read(p.id)).pending, isTrue);
    online = true;
    final recreated = ProgramService(client: authenticated);
    final state = (await recreated.loadAll([p]))[p.id]!;
    expect(rpcCalls, 1);
    expect(
      recreated.syncPending,
      isFalse,
      reason: '${recreated.lastSyncError}',
    );
    expect(state.completedCount(p), 2);
    expect(state.pending, isFalse);
    expect(state.saved, isTrue);
    await authenticated.auth.signOut(scope: SignOutScope.local);
    expect(
      (await ProgramService(client: authenticated).read(p.id)).completed,
      isEmpty,
    );
    account = '00000000-0000-0000-0000-000000000002';
    await authenticated.auth.signInWithPassword(
      email: 'other@example.com',
      password: 'test',
    );
    expect(
      (await ProgramService(client: authenticated).read(p.id)).completed,
      isEmpty,
    );
    await expectLater(service.update(p.id, saved: false), throwsStateError);
  });
  test(
    'progress survives service recreation; repeated completion is idempotent',
    () async {
      final p = programCatalog.first;
      final service = ProgramService(client: client);
      await service.update(p.id, open: true);
      await service.update(p.id, completedLesson: p.lessons.first.id);
      await service.update(p.id, completedLesson: p.lessons.first.id);
      final recreated = ProgramService(client: client);
      var state = await recreated.read(p.id);
      expect(state.completedCount(p), 1);
      expect(state.nextLessonId(p), p.lessons[1].id);
      for (final lesson in p.lessons) {
        await recreated.update(p.id, completedLesson: lesson.id);
      }
      state = await recreated.read(p.id);
      expect(state.isComplete(p), isTrue);
      expect(state.nextLessonId(p), isNull);
    },
  );
  test(
    'device merge keeps both completions and newest bookmark preference',
    () {
      const a = ProgramProgress(
        saved: true,
        savedAt: '2026-10-25',
        completed: {'a'},
      );
      const b = ProgramProgress(
        saved: false,
        savedAt: '2026-10-26',
        completed: {'b'},
      );
      expect(a.merge(b).completed, {'a', 'b'});
      expect(a.merge(b).saved, isFalse);
    },
  );
  test(
    'recommendations prioritize unfinished programs over topic preference',
    () {
      final ongoing = programCatalog.last;
      final items = ProgramService.recommend(
        programCatalog,
        {ongoing.id: const ProgramProgress(started: true)},
        {programCatalog.first.topic},
      );
      expect(items.first.id, ongoing.id);
      expect(items[1].id, programCatalog.first.id);
    },
  );
  testWidgets('start opens a lesson; complete returns to updated progress', (
    tester,
  ) async {
    final p = programCatalog.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [PbhPalette.resolve('pbh')],
        ),
        home: ProgramDetailScreen(
          program: p,
          service: ProgramService(client: client),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final start = find.text('Iniciar programa');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Coloque em prática'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Coloque em prática'), findsOneWidget);
    final complete = find.text('Concluir aula');
    await tester.scrollUntilVisible(
      complete,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(complete);
    await tester.pumpAndSettle();
    expect(find.text('Escrever uma reflexão'), findsOneWidget);
    expect(find.text('Definir meu próximo passo'), findsOneWidget);
    await tester.tap(find.text('Voltar ao programa'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 4 aulas concluídas'), findsOneWidget);
    expect(find.text('Continuar programa'), findsOneWidget);
  });
}

class _LocalProgramService extends ProgramService {
  _LocalProgramService(SupabaseClient client) : super(client: client);
  @override
  Future<List<ProgramModel>> availableCatalog() async => programCatalog;
}

class _MemoryAdminService extends ContentAdminService {
  _MemoryAdminService(SupabaseClient client) : super(client: client);
  ProgramModel? saved;
  @override
  Future<List<Map<String, dynamic>>> list() async => [
    {...(saved ?? programCatalog.first).toJson(), 'published': true},
  ];
  @override
  Future<void> save(ProgramModel program, {required bool published}) async {
    saved = program;
  }
}
