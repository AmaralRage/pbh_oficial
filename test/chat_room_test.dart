import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    Uint8List? photo, {
    double dim = .54,
  }) async {}
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
  Future<void> typing(String thread, bool active) async {}
  @override
  Future<DateTime?> peerTyping(String thread) async => null;
  @override
  RealtimeChannel watchTyping(String thread, void Function() changed) =>
      client.channel('typing-fixture');
  @override
  Future<bool> muted(String thread) async => false;
  @override
  Future<List<ChatMessage>> replyContext(
    String thread,
    List<String> ids,
  ) async => [];
  @override
  Future<void> send(String thread, ChatDraft draft) async {
    attempts.add(draft);
    if (attempts.length == 1) throw StateError('lost response');
  }
}

void main() {
  testWidgets(
    'microphone tap opens recording and cancellation restores the action',
    (tester) async {
      final service = (await tester.runAsync(() async => _Chat()))!;
      const channel = MethodChannel('com.llfbandit.record/messages');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'hasPermission') return false;
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatRoomScreen(
            threadId: 'cc070000-0000-4000-8000-000000000001',
            service: service,
            localStore: _MemoryStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gravar áudio'));
      await tester.pumpAndSettle();
      expect(find.text('Permita o microfone'), findsOneWidget);
      expect(find.textContaining('Permita o microfone'), findsOneWidget);
      expect(service.attempts, isEmpty);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Permita o microfone'), findsNothing);
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Gravar áudio',
        ),
      );
      expect(button.onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
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
      expect(find.byTooltip('Gravar áudio'), findsOneWidget);
      expect(find.byTooltip('Enviar mensagem'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Olá, irmão!');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Enviar mensagem'), findsOneWidget);
      expect(find.byTooltip('Gravar áudio'), findsNothing);
      await tester.tap(find.byTooltip('Enviar mensagem'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Olá, irmão!'), findsNWidgets(2));
      expect(find.text('Envio não confirmado'), findsOneWidget);
      expect(service.attempts, hasLength(1));
      await tester.tap(find.text('Tentar novamente'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(service.attempts, hasLength(2));
      expect(service.attempts.first.id, service.attempts.last.id);
      expect(find.text('Olá, irmão!'), findsNothing);
      expect(find.byTooltip('Gravar áudio'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
  );
}
