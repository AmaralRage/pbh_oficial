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
import 'package:pbh_oficial/widgets/chat_date_separator.dart';
import 'package:pbh_oficial/widgets/chat_message_frame.dart';
import 'package:pbh_oficial/screens/chat_inbox_screen.dart';

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

class _InboxService extends _Service {
  @override
  Future<List<ChatThread>> inbox({
    ChatThread? before,
    String? thread,
    String query = '',
  }) async => [
    ChatThread(
      id: 'thread',
      peerId: 'peer',
      name: 'Arthur Morgan com um nome comprido',
      lastAt: DateTime.now(),
      activityAt: DateTime.now(),
      peerReadAt: DateTime.now(),
      muted: true,
      unread: 12,
      audioDurationMs: 35000,
    ),
  ];
  @override
  RealtimeChannel watchInbox(
    void Function() changed,
    void Function(bool)? connection,
  ) => client.channel('inbox-fixture');
}

class _HistoryService extends _Service {
  final now = DateTime.now();
  late final rows = List.generate(
    40,
    (i) => ChatMessage(
      id: 'history-$i',
      senderId: 'other',
      body: 'Mensagem do histórico $i',
      createdAt: now.subtract(Duration(minutes: i)),
      expiresAt: now.add(const Duration(days: 7)),
    ),
  );
  void Function(bool)? changed;
  int readCalls = 0;
  int unreadCount = 0;
  @override
  Future<List<ChatMessage>> messages(
    String thread, {
    ChatMessage? before,
  }) async => before == null ? List.of(rows) : [];
  @override
  Future<List<ChatThread>> inbox({
    ChatThread? before,
    String? thread,
    String query = '',
  }) async => [
    ChatThread(
      id: 'thread',
      peerId: 'other',
      name: 'Membro',
      lastAt: now,
      activityAt: now,
      peerReadAt: now,
      unread: unreadCount,
    ),
  ];
  @override
  Future<void> markRead(String thread, String through) async {
    readCalls++;
    unreadCount = 0;
  }

  @override
  RealtimeChannel watchRoom(
    String thread,
    void Function(bool) change,
    void Function(bool) connection,
  ) {
    changed = change;
    return client.channel('history-fixture');
  }
}

void main() {
  testWidgets(
    'chat supports enlarged text and accessible reply action on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final service = (await tester.runAsync(() async => _HistoryService()))!;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: ChatRoomScreen(
            threadId: 'thread',
            service: service,
            localStore: _Store(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      service.typingChanged!();
      await tester.pump();
      await tester.pump();
      expect(find.text('digitando…'), findsOneWidget);
      expect(find.byTooltip('Gravar áudio'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
  testWidgets(
    'unread marker keeps the original boundary after marking messages read',
    (tester) async {
      final service = (await tester.runAsync(() async => _HistoryService()))!;
      service.unreadCount = 3;
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
      expect(find.text('Mensagens novas · 3'), findsOneWidget);
      expect(service.unreadCount, 0);
      service.changed!(false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Mensagens novas · 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
  testWidgets(
    'history stays away from bottom on arrival and jump clears new-message counter',
    (tester) async {
      final service = (await tester.runAsync(() async => _HistoryService()))!;
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
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Voltar para mensagens recentes'), findsOneWidget);
      final readBefore = service.readCalls;
      service.rows.insert(
        0,
        ChatMessage(
          id: 'new-incoming',
          senderId: 'other',
          body: 'Acabou de chegar',
          createdAt: service.now.add(const Duration(seconds: 1)),
          expiresAt: service.now.add(const Duration(days: 7)),
        ),
      );
      service.changed!(false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(service.readCalls, readBefore);
      await tester.tap(find.byTooltip('Voltar para mensagens recentes'));
      await tester.pumpAndSettle();
      expect(find.text('Acabou de chegar'), findsOneWidget);
      expect(find.byTooltip('Voltar para mensagens recentes'), findsNothing);
      expect(service.readCalls, greaterThan(readBefore));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
  testWidgets(
    'inbox fits unread audio and mute state at 320 px with one new-conversation action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final service = (await tester.runAsync(() async => _InboxService()))!;
      await tester.pumpWidget(
        MaterialApp(home: ChatInboxScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Áudio · 0:35'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
      expect(find.text('Nova conversa'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
  testWidgets(
    'reference layout keeps incoming text and outgoing audio readable at 320 px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const ChatMessageFrame(
                    mine: false,
                    grouped: false,
                    time: '09:17',
                    read: false,
                    child: Text(
                      'Uma mensagem recebida com texto maior para conferir a leitura.',
                    ),
                  ),
                  ChatMessageFrame(
                    mine: true,
                    grouped: false,
                    time: '09:18',
                    read: true,
                    child: ChatAudioPlayer(
                      load: () async => Uint8List(0),
                      durationMs: 65000,
                      format: 'm4a',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('09:17'), findsOneWidget);
      expect(find.text('1:05'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'chat grouping respects author, five-minute gaps and day boundaries',
    () {
      ChatMessage at(DateTime date, [String sender = 'other']) => ChatMessage(
        id: date.toString(),
        senderId: sender,
        body: 'Mensagem',
        createdAt: date,
        expiresAt: date.add(const Duration(days: 7)),
      );
      final now = DateTime(2026, 11, 9, 12);
      expect(chatDateLabel(now, now), 'Hoje');
      expect(chatDateLabel(DateTime(2026, 11, 8, 23), now), 'Ontem');
      expect(chatDateLabel(DateTime(2026, 11, 7), now), '07/11/2026');
      expect(
        connectedChatMessages(
          at(now),
          at(now.subtract(const Duration(minutes: 4))),
        ),
        isTrue,
      );
      expect(
        connectedChatMessages(
          at(now),
          at(now.subtract(const Duration(minutes: 6))),
        ),
        isFalse,
      );
      expect(connectedChatMessages(at(now), at(now, 'me')), isFalse);
      expect(
        connectedChatMessages(
          at(DateTime(2026, 11, 9)),
          at(DateTime(2026, 11, 8, 23, 59)),
        ),
        isFalse,
      );
    },
  );
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
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
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
