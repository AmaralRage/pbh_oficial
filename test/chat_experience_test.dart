import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/chat_models.dart';
import 'package:pbh_oficial/services/chat_service.dart';
import 'package:pbh_oficial/services/chat_local_store.dart';
import 'package:pbh_oficial/screens/chat_room_screen.dart';
import 'package:pbh_oficial/widgets/chat_audio_player.dart';
import 'package:pbh_oficial/widgets/chat_reply_swipe.dart';
import 'package:pbh_oficial/widgets/chat_message_search.dart';

final message = ChatMessage(
  id: 'message',
  senderId: 'other',
  body: 'Disciplina diária',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(days: 7)),
);

class _Store extends ChatLocalStore {
  @override
  Future<ChatDraft?> load(String user, String thread) async => null;
  @override
  Future<void> save(String user, String thread, ChatDraft draft) async {}
  @override
  Future<Map<String, dynamic>> wallpaper(String user, String thread) async =>
      {};
}

class _Service extends ChatService {
  _Service()
    : super(
        client: SupabaseClient(
          'https://fixture.invalid',
          'public',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  String get userId => 'me';
  bool isMuted = false;
  final typingStates = <bool>[];
  void Function()? typingChanged;
  @override
  Future<List<ChatMessage>> messages(
    String thread, {
    ChatMessage? before,
  }) async => [message];
  @override
  Future<List<ChatThread>> inbox({
    ChatThread? before,
    String? thread,
    String query = '',
  }) async => [];
  @override
  Future<void> markRead(String thread, String through) async {}
  @override
  Future<List<ChatMessage>> replyContext(
    String thread,
    List<String> ids,
  ) async => ids.contains(message.id) ? [message] : [];
  @override
  Future<List<ChatMessage>> searchMessages(
    String thread,
    String query, {
    ChatMessage? before,
  }) async => query.toLowerCase().contains('disciplina') ? [message] : [];
  @override
  Future<bool> muted(String thread) async => isMuted;
  @override
  Future<void> setMuted(String thread, bool value) async {
    isMuted = value;
  }

  @override
  Future<void> typing(String thread, bool active) async {
    typingStates.add(active);
  }

  @override
  Future<DateTime?> peerTyping(String thread) async =>
      DateTime.now().add(const Duration(seconds: 1));
  @override
  RealtimeChannel watchRoom(
    String thread,
    void Function(bool) changed,
    void Function(bool) connection,
  ) => client.channel('room');
  @override
  RealtimeChannel watchTyping(String thread, void Function() changed) {
    typingChanged = changed;
    return client.channel('typing');
  }

  @override
  Future<void> close(RealtimeChannel channel) async {}
}

void main() {
  testWidgets(
    'audio speed cycles through 1x, 1.5x, 2x without downloading audio',
    (tester) async {
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAudioPlayer(
              load: () async {
                loads++;
                return Uint8List(0);
              },
              durationMs: 120000,
              format: 'm4a',
            ),
          ),
        ),
      );
      expect(find.text('2:00'), findsOneWidget);
      for (final next in ['1,5×', '2×', '1×']) {
        await tester.tap(find.byType(TextButton));
        await tester.pump();
        expect(find.text(next), findsOneWidget);
      }
      expect(loads, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reply swipe requires deliberate horizontal movement and never dismisses message',
    (tester) async {
      var replies = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatReplySwipe(
              onReply: () => replies++,
              child: const SizedBox(
                width: 250,
                height: 70,
                child: Text('Mensagem'),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.text('Mensagem'), const Offset(10, 0));
      await tester.pump();
      expect(replies, 0);
      await tester.drag(find.text('Mensagem'), const Offset(100, 0));
      await tester.pump();
      expect(replies, 1);
      expect(find.text('Mensagem'), findsOneWidget);
    },
  );
  testWidgets(
    'conversation search returns original message for reply and shows empty state',
    (tester) async {
      final service = (await tester.runAsync(() async => _Service()))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageSearch(service: service, threadId: 'thread'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'nada');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma mensagem encontrada.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'disciplina');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(message.body), findsOneWidget);
      expect(find.byIcon(Icons.reply_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
  testWidgets(
    'chat swipe previews original, typing expires, mute can be reversed',
    (tester) async {
      final service = (await tester.runAsync(() async => _Service()))!;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatRoomScreen(
            threadId: 'thread',
            service: service,
            localStore: _Store(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text(message.body), const Offset(110, 0));
      await tester.pumpAndSettle();
      expect(find.text('Respondendo a uma mensagem'), findsOneWidget);
      expect(find.text(message.body), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'Olá');
      await tester.pump();
      expect(service.typingStates.last, true);
      await tester.pump(const Duration(seconds: 4));
      expect(service.typingStates.last, false);
      service.typingChanged!();
      await tester.pump();
      await tester.pump();
      expect(find.text('digitando…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('digitando…'), findsNothing);
      await tester.tap(find.byTooltip('Personalizar conversa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Silenciar conversa'));
      await tester.pumpAndSettle();
      expect(service.isMuted, true);
      await tester.tap(find.byTooltip('Personalizar conversa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ativar notificações'));
      await tester.pumpAndSettle();
      expect(service.isMuted, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
}
