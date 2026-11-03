import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/widgets/member_handle.dart';
import 'package:pbh_oficial/widgets/profile_surface.dart';

void main() {
  const owner = 'ad300000-0000-4000-8000-000000000001';
  late SupabaseClient client;
  final writes = <String>[];
  var visibleHandle = 'initial_handle';
  setUp(() async {
    writes.clear();
    visibleHandle = 'initial_handle';
    client = SupabaseClient(
      'https://test.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) async {
        Object body = visibleHandle;
        int code = 200;
        if (r.url.path.endsWith('/token')) {
          body = {
            'access_token': 'token',
            'refresh_token': 'refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': owner,
              'aud': 'authenticated',
              'email': 'test@example.invalid',
              'created_at': '2026-11-03T12:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          };
        } else if (r.url.path.endsWith('/set_member_handle')) {
          final h = (jsonDecode(r.body) as Map)['p_handle'] as String;
          writes.add(h);
          if (h == 'taken') {
            code = 409;
            body = {
              'message': 'Este nome de usuário já está em uso.',
              'code': '23505',
            };
          } else {
            body = h;
          }
        }
        return http.Response(
          jsonEncode(body),
          code,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'test@example.invalid',
      password: 'test',
    );
  });
  tearDown(() => client.dispose());
  testWidgets('owner edits handle and a duplicate remains editable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberHandle(
            userId: owner,
            client: client,
            child: const Text('Arthur Morgan'),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('@initial_handle'), findsNothing);
    await tester.tap(find.text('Arthur Morgan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar @usuário'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'taken');
    await tester.tap(find.text('Salvar'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Este nome de usuário já está em uso.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'arthur_morgan');
    await tester.tap(find.text('Salvar'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('@arthur_morgan'), findsNothing);
    expect(writes, ['taken', 'arthur_morgan']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('hover reveals the handle without a permanent profile line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MemberHandle(
              userId: 'ad300000-0000-4000-8000-000000000002',
              client: client,
              child: const Text('Arthur Morgan'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('@initial_handle'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Arthur Morgan')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('@initial_handle'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpAndSettle();
  });
  testWidgets('automatic handle reminds only the owner to personalize it', (
    tester,
  ) async {
    visibleHandle = 'm_' + owner.replaceAll('-', '');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberHandle(
            userId: owner,
            client: client,
            child: const Text('Arthur Morgan'),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('@$visibleHandle'), findsOneWidget);
    expect(
      find.text('Este é seu nome automático. Toque para personalizar.'),
      findsOneWidget,
    );
    await tester.tap(find.text('@$visibleHandle'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'personalizado');
    await tester.tap(find.text('Salvar'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.text('@personalizado'), findsNothing);
    expect(
      find.text('Este é seu nome automático. Toque para personalizar.'),
      findsNothing,
    );
    await tester.tap(find.text('Arthur Morgan'));
    await tester.pumpAndSettle();
    expect(find.text('@personalizado'), findsOneWidget);
  });
  testWidgets('handle menu carries glass preference into its overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSurfaceScope(
            enabled: true,
            child: MemberHandle(
              userId: owner,
              client: client,
              child: const Text('Arthur Morgan'),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.tap(find.text('Arthur Morgan'));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('@initial_handle'), findsOneWidget);
    expect(find.text('Copiar @usuário'), findsOneWidget);
    expect(find.text('Editar @usuário'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
