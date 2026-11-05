import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/widgets/community_activity_sheet.dart';
import 'package:pbh_oficial/widgets/community_activity.dart';

class _ActivityService extends CommunityService {
  _ActivityService(SupabaseClient client) : super(client: client);
  int unread = 31;
  DateTime? through;
  final offsets = <int>[];
  @override
  String? get currentUserId => 'owner';
  @override
  Stream<AuthState> get authChanges => const Stream.empty();
  @override
  Future<int> activityUnreadCount() async => unread;
  @override
  Future<List<Map<String, dynamic>>> replyActivity() async => [item(0)];
  @override
  Future<void> markActivityRead(DateTime date) async {
    through = date;
    unread = 0;
  }

  @override
  Future<List<Map<String, dynamic>>> activityPage({int offset = 0}) async {
    offsets.add(offset);
    return [item(30)];
  }
}

Map<String, dynamic> item(int n) => {
  'id': '$n',
  'actor_id': 'actor',
  'actor_name': 'Arthur Morgan',
  'actor_avatar_url': null,
  'kind': 'post_comment',
  'comment_id': 'comment-$n',
  'post_id': 'post',
  'created_at': DateTime.utc(
    2026,
    11,
    5,
    12,
  ).subtract(Duration(minutes: n)).toIso8601String(),
  'read_at': null,
  'preview': 'Seu esforço inspira a comunidade.',
};
void main() {
  late SupabaseClient client;
  setUp(
    () => client = SupabaseClient(
      'https://test.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
  tearDown(() => client.dispose());
  testWidgets(
    'activity shows current identity, preview, exact target and read-all cutoff',
    (tester) async {
      final service = _ActivityService(client);
      Map<String, dynamic>? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Abrir'),
                onPressed: () async {
                  selected = await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CommunityActivitySheet(
                      service: service,
                      initialItems: [item(0)],
                      unreadCount: 31,
                      onPreferences: () {},
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(
        find.text('Arthur Morgan comentou na sua publicação'),
        findsOneWidget,
      );
      expect(find.text('Seu esforço inspira a comunidade.'), findsOneWidget);
      expect(find.text('31 atividades não lidas'), findsOneWidget);
      await tester.tap(find.text('Marcar todas como lidas'));
      await tester.pumpAndSettle();
      expect(service.through, DateTime.utc(2026, 11, 5, 12));
      expect(find.text('Você está em dia'), findsOneWidget);
      await tester.tap(find.text('Arthur Morgan comentou na sua publicação'));
      await tester.pumpAndSettle();
      expect(selected?['comment_id'], 'comment-0');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'activity paginates without dropping rows with large mobile text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _ActivityService(client);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: CommunityActivitySheet(
                service: service,
                initialItems: List.generate(30, item),
                unreadCount: 31,
                onPreferences: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Carregar mais atividades'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Carregar mais atividades'));
      await tester.pumpAndSettle();
      expect(service.offsets, [30]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('closing after read-all refreshes the parent badge immediately', (
    tester,
  ) async {
    final service = _ActivityService(client);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityActivityButton(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    await tester.tap(find.byTooltip('Atividade da comunidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar todas como lidas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fechar atividade'));
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
