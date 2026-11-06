import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/private_support_service.dart';
import 'package:pbh_oficial/widgets/support_reply_notice.dart';

class _Support extends PrivateSupportService {
  _Support({required SupabaseClient client}) : super(client: client);
  bool offline = false;
  @override
  String? get currentUserId => 'member';
  @override
  Stream<AuthState> get authChanges => const Stream.empty();
  @override
  Future<int> unreadCount() async {
    if (offline) throw StateError('offline');
    return 2;
  }
}

void main() {
  late SupabaseClient client;
  setUp(
    () => client = SupabaseClient(
      'https://test.supabase.co',
      'public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
  tearDown(() => client.dispose());
  testWidgets(
    'support replies show an unread indicator and can retry on failure',
    (tester) async {
      final service = _Support(client: client)..offline = true;
      var count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SupportReplyNotice(
              service: service,
              onChanged: () {},
              onCountChanged: (value) => count = value,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Tentar novamente'), findsOneWidget);
      service.offline = false;
      await tester.tap(find.textContaining('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(count, 2);
      expect(find.text('A equipe respondeu ao seu pedido'), findsOneWidget);
      expect(find.textContaining('2 respostas não lidas'), findsOneWidget);
    },
  );
}
