import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/chat_models.dart';
import 'package:pbh_oficial/screens/chat_room_screen.dart';
import 'package:pbh_oficial/services/chat_service.dart';
import 'package:pbh_oficial/services/chat_local_store.dart';

class _MemoryStore extends ChatLocalStore {
  @override
  Future<ChatDraft?> load(String user, String thread) async => null;
  @override
  Future<void> save(String user, String thread, ChatDraft draft) async {}
  @override
  Future<Map<String, dynamic>> wallpaper(String user, String thread) async =>
      {};
  @override
  Future<void> saveWallpaper(
    String user,
    String thread,
    String preset,
    Uint8List? photo,
  ) async {}
}

class _Chat extends ChatService {
  _Chat()
    : super(
        client: SupabaseClient(
          'https://fixture.invalid',
          'public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final attempts = <ChatDraft>[];
  @override
  String get userId => 'member';
  @override
  Future<List<ChatMessage>> messages(
    String thread, {
    ChatMessage? before,
  }) async => [];
  @override
  Future<List<ChatThread>> inbox({
    ChatThread? before,
    String? thread,
    String query = '',
  }) async => [];
  @override
  RealtimeChannel watchRoom(
    String thread,
    void Function(bool) changed,
    void Function(bool) connection,
  ) => client.channel('fixture');
  @override
  Future<void> close(RealtimeChannel channel) async {}
  @override
  Future<void> send(String thread, ChatDraft draft) async {
    attempts.add(draft);
    if (attempts.length == 1) throw StateError('lost response');
  }
}

void main() {
  testWidgets(
    'small-screen chat keeps failed draft and retries with the same UUID',
    (tester) async {
      final service = (await tester.runAsync(() async => _Chat()))!;
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ChatRoomScreen(
            threadId: 'cc070000-0000-4000-8000-000000000001',
            service: service,
            localStore: _MemoryStore(),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Mensagens e anexos desaparecem após 7 dias.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Olá, irmão!');
      await tester.tap(find.byTooltip('Enviar mensagem'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Olá, irmão!'), findsOneWidget);
      expect(service.attempts, hasLength(1));
      await tester.tap(find.byTooltip('Enviar mensagem'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(service.attempts, hasLength(2));
      expect(service.attempts.first.id, service.attempts.last.id);
      expect(find.text('Olá, irmão!'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
  );
}
