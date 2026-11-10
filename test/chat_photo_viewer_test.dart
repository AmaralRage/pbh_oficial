import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/chat_models.dart';
import 'package:pbh_oficial/services/chat_service.dart';
import 'package:pbh_oficial/screens/chat_photo_viewer_screen.dart';

class _PhotoService extends ChatService {
  _PhotoService()
    : super(
        client: SupabaseClient(
          'https://fixture.invalid',
          'public',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  @override
  String get userId => 'member';
  int loads = 0;
  bool denyExport = false;
  final bytes = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 16, height: 32)),
  );
  @override
  Future<Uint8List> photo(String thread, ChatMessage message) async {
    loads++;
    if (denyExport && loads > 1) throw StateError('Access revoked');
    return bytes;
  }
}

ChatMessage _message() => ChatMessage(
  id: 'photo',
  senderId: 'other',
  body: 'Foto da conversa',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  imagePath: 'member/thread/photo.jpg',
);
void main() {
  testWidgets('viewer removes expired image and disables export', (
    tester,
  ) async {
    final service = (await tester.runAsync(() async => _PhotoService()))!;
    final message = ChatMessage(
      id: 'photo',
      senderId: 'other',
      body: '',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      imagePath: 'member/thread/photo.jpg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ChatPhotoViewerScreen(
          threadId: 'thread',
          message: message,
          service: service,
          save: (_, __, ___) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    // Virtual time expires the photo; wall-clock startup under load cannot.
    await tester.pump(const Duration(minutes: 11));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Foto indisponível ou expirada.'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Salvar foto',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => service.client.dispose());
  });
  testWidgets(
    'viewer zooms and rechecks access separately for save and share',
    (tester) async {
      final service = (await tester.runAsync(() async => _PhotoService()))!;
      var saves = 0, shares = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPhotoViewerScreen(
            threadId: 'thread',
            message: _message(),
            service: service,
            save: (bytes, name, mime) async {
              saves++;
              expect(bytes, service.bytes);
              expect(name, startsWith('pbh-foto-'));
              expect(mime, 'image/jpeg');
              return true;
            },
            share: (bytes, name, origin) async {
              shares++;
              expect(bytes, service.bytes);
              expect(name, endsWith('.jpg'));
              expect(origin?.width, greaterThan(0));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.loads, 1);
      await tester.tap(find.byTooltip('Ampliar foto'));
      await tester.pump();
      expect(find.byTooltip('Reduzir foto'), findsOneWidget);
      await tester.tap(find.byTooltip('Reduzir foto'));
      await tester.pump();
      await tester.tap(find.byTooltip('Salvar foto'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(service.loads, 2);
      await tester.tap(find.byTooltip('Compartilhar foto'));
      await tester.pumpAndSettle();
      expect(shares, 1);
      expect(service.loads, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
  testWidgets(
    'viewer refuses export after permission changes and respects cancellation',
    (tester) async {
      final service = (await tester.runAsync(() async => _PhotoService()))!;
      service.denyExport = true;
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPhotoViewerScreen(
            threadId: 'thread',
            message: _message(),
            service: service,
            save: (_, __, ___) async {
              saves++;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Salvar foto'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(
        find.textContaining('Não foi possível acessar a foto'),
        findsOneWidget,
      );
      service.denyExport = false;
      await tester.tap(find.byTooltip('Salvar foto'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('Foto salva.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => service.client.dispose());
    },
  );
}
