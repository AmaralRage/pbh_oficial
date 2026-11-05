import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/widgets/admin_member_picker.dart';

void main() {
  late SupabaseClient client;
  final queries = <String>[];
  setUp(() {
    queries.clear();
    client = SupabaseClient(
      'https://test.supabase.co',
      'public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final query = (jsonDecode(request.body) as Map)['p_query'] as String;
        queries.add(query);
        final rows = query.isEmpty
            ? <Object>[]
            : [
                {
                  'user_id': 'ad300000-0000-4000-8000-000000000001',
                  'name': 'Arthur Morgan',
                  'handle': 'arthur_morgan',
                  'avatar_url': null,
                  'joined_at': '2026-01-01T12:00:00Z',
                },
              ];
        return http.Response(
          jsonEncode(rows),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDown(() async => client.dispose());
  testWidgets('member can be selected by name without entering an email', (
    tester,
  ) async {
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AdminMemberPicker(client: client),
                );
              },
              child: const Text('Escolher'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Escolher'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Arthur');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(queries.last, 'Arthur');
    expect(find.text('Arthur Morgan'), findsOneWidget);
    await tester.tap(find.text('Arthur Morgan'));
    await tester.pumpAndSettle();
    expect(selected?['user_id'], 'ad300000-0000-4000-8000-000000000001');
    expect(selected?.containsKey('email'), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'public search uses handles and hides administrative identifiers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMemberPicker(client: client, publicSearch: true),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '@arthur_morgan');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buscar membros'), findsOneWidget);
      expect(find.text('@arthur_morgan'), findsWidgets);
      expect(find.textContaining('ID:'), findsNothing);
      expect(find.textContaining('Desde '), findsNothing);
      expect(queries.last, '@arthur_morgan');
      expect(tester.takeException(), isNull);
    },
  );
}
