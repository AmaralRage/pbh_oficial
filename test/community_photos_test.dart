import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/community_photo.dart';
import 'package:pbh_oficial/models/community_post_model.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/screens/community_post_composer.dart';
import 'package:pbh_oficial/screens/community_screen.dart';
import 'package:pbh_oficial/widgets/community_photo_gallery.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _Posts extends CommunityService {
  _Posts(SupabaseClient client) : super(client: client);
  bool fail = true;
  final ids = <String?>[];
  final counts = <int>[];
  @override
  Future<List<CommunityPostModel>> fetchPosts({
    int filterIndex = 0,
    int offset = 0,
    int limit = 20,
    String search = '',
    String? topic,
  }) async => [];
  @override
  Future<CommunityStats> fetchStats() async =>
      const CommunityStats(posts: 0, comments: 0, likes: 0);
  @override
  Future<void> createPost(
    String content, {
    String? achievementTag,
    String? topic,
    List<CommunityPhoto> photos = const [],
    String? draftId,
  }) async {
    ids.add(draftId);
    counts.add(photos.length);
    if (fail) throw StateError('offline');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    'one empty community invites real posts and requires login to publish',
    (tester) async {
      var logins = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityScreen(
              service: _Posts(client),
              isAuthenticated: false,
              onRequireLogin: () => logins++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Compartilhe sua jornada'), findsOneWidget);
      expect(find.text('Em destaque'), findsOneWidget);
      expect(find.text('Samuel'), findsNothing);
      await tester.tap(find.text('Fotos'));
      await tester.pump();
      expect(logins, 1);
      expect(find.byType(CommunityPostComposer), findsNothing);
      await tester.tap(find.byTooltip('Sobre a comunidade'));
      await tester.pumpAndSettle();
      expect(find.text('Uma comunidade, muitas jornadas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'gallery opens the selected photo full screen and moves between images',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: CommunityPhotoGallery(urls: List.filled(4, '')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Ampliar foto 3',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anexo 3 de 4'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Anexo 4 de 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'photos accept bounded real image signatures and retain media in copies',
    () {
      expect(CommunityPhoto(_png).mime, 'image/png');
      final html = CommunityPhoto(
        Uint8List.fromList(
          utf8.encode(
            '<!doctype html><html><body><canvas></canvas></body></html>',
          ),
        ),
      );
      expect(html.extension, 'html');
      expect(html.mime, 'text/plain');
      expect(html.isVideo, false);
      final gif = CommunityPhoto(
        Uint8List.fromList(ascii.encode('GIF89a123456')),
      );
      expect(gif.mime, 'image/gif');
      expect(gif.isVideo, false);
      final mp4 = CommunityPhoto(
        Uint8List.fromList([0, 0, 0, 24, ...ascii.encode('ftypmp42')]),
      );
      expect(mp4.mime, 'video/mp4');
      expect(mp4.isVideo, true);
      final oversizedGif = Uint8List(CommunityPhoto.maxGifBytes + 1)
        ..setAll(0, ascii.encode('GIF89a'));
      expect(() => CommunityPhoto(oversizedGif), throwsArgumentError);
      expect(
        () => CommunityPhoto(
          Uint8List.fromList([0, 0, 0, 24, ...ascii.encode('ftypheic')]),
        ),
        throwsArgumentError,
      );
      expect(
        () => CommunityPhoto(Uint8List(CommunityPhoto.maxBytes + 1)),
        throwsArgumentError,
      );
      expect(
        () => CommunityPhoto(Uint8List.fromList(utf8.encode('<svg></svg>'))),
        throwsArgumentError,
      );
      final post = CommunityPostModel.fromMap({
        'id': 'post',
        'user_id': 'user',
        'content': 'Relato',
        'created_at': '2026-10-30T10:00:00Z',
        'image_paths': ['user/post/0.jpg'],
      });
      final copied = post.copyWith(isSaved: true, imageUrls: ['signed']);
      expect(copied.imagePaths, ['user/post/0.jpg']);
      expect(copied.imageUrls, ['signed']);
      expect(copied.copyWith(isFollowing: true).imageUrls, ['signed']);
    },
  );
  testWidgets(
    'composer keeps photos and text on failure and retries the same draft',
    (tester) async {
      final service = _Posts(client);
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityPostComposer(
                      service: service,
                      pickPhotos: (limit) async => [
                        CommunityPhoto(_png),
                        CommunityPhoto(_png),
                      ],
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Minha primeira caminhada!',
      );
      await tester.scrollUntilVisible(
        find.text('Adicionar fotos (0/4)'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Adicionar fotos (0/4)'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remover foto 2'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Publicar na comunidade'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Publicar na comunidade'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Seu relato e suas fotos continuam aqui'),
        findsOneWidget,
      );
      expect(service.counts, [2]);
      service.fail = false;
      await tester.scrollUntilVisible(
        find.text('Publicar na comunidade'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Publicar na comunidade'));
      await tester.pumpAndSettle();
      expect(service.counts, [2, 2]);
      expect(service.ids[0], service.ids[1]);
      expect(find.text('Abrir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('composer confirms discarding an unpublished draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CommunityPostComposer(service: _Posts(client))),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Meu relato');
    await tester.tap(find.byTooltip('Fechar publicação'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar publicação?'), findsOneWidget);
    await tester.tap(find.text('Continuar escrevendo'));
    await tester.pumpAndSettle();
    expect(find.text('Meu relato'), findsOneWidget);
  });
}
