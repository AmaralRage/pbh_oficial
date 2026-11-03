import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Use bundled test font data rather than fetching fonts during navigation tests.
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pbh_oficial/models/community_post_model.dart';
import 'package:pbh_oficial/screens/public_member_profile_screen.dart';
import 'package:pbh_oficial/widgets/community_post_card.dart';

class _Fonts extends AssetManifest {
  @override
  List<String> listAssets() => ['Manrope-Regular.ttf'];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'notification opens and highlights an older reply outside the first page',
    (tester) async {
      const member = '00000000-0000-0000-0000-000000000001';
      SharedPreferences.setMockInitialValues({});
      fonts.assetManifest = _Fonts();
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'Manrope-Regular.ttf') return ByteData(0);
          return null;
        },
      );
      var profileRequests = 0;
      await tester.runAsync(
        () => Supabase.initialize(
          url: 'https://test.supabase.co',
          publishableKey: 'public-key',
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            localStorage: EmptyLocalStorage(),
            detectSessionInUri: false,
          ),
          httpClient: MockClient((request) async {
            Object? result;
            if (request.url.path.endsWith('community_comment_feed') ||
                request.url.path.endsWith('community_comment_context')) {
              result = [
                {
                  'id': 'comment',
                  'user_id': member,
                  'author_name': 'Pessoa real',
                  'content': 'Comentário de teste',
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                },
                {
                  'id': 'reply',
                  'reply_to_id': 'comment',
                  'user_id': member,
                  'author_name': 'Resposta',
                  'content': 'Resposta encadeada',
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                },
              ];
              if (request.url.path.endsWith('community_comment_feed'))
                result = (result as List)
                    .where((row) => row['id'] != 'reply')
                    .toList();
            } else if (request.url.path.endsWith('community_member_profile')) {
              profileRequests++;
              expect(jsonDecode(request.body), {'p_user_id': member});
            } else if (request.url.path.endsWith(
              'community_sample_post_feed',
            )) {
              result = <String, dynamic>{};
            } else {
              throw StateError('Unexpected request: ${request.url.path}');
            }
            return http.Response(
              jsonEncode(result),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      addTearDown(() async {
        fonts.assetManifest = null;
        fonts.clearCache();
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(
              post: CommunityPostModel(
                id: 'post',
                userId: member,
                authorName: 'Autor',
                createdAt: DateTime.now(),
                content: 'Publicação',
                likes: 0,
                comments: 2,
                likedByMe: false,
              ),
              focusCommentId: 'reply',
              isAuthenticated: false,
              onRequireLogin: () {},
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pessoa real'), findsOneWidget);
      expect(find.text('Resposta encadeada'), findsOneWidget);
      expect(find.text('Resposta encadeada'), findsOneWidget);
      await tester.tap(find.text('Ocultar respostas'));
      await tester.pumpAndSettle();
      expect(find.text('Resposta encadeada'), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CircleAvatar).last);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PublicMemberProfileScreen), findsOneWidget);
      expect(profileRequests, greaterThanOrEqualTo(1));
      expect(find.text('Tentar novamente'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Pessoa real'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final beforeSample = profileRequests;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(
              post: CommunityPostModel(
                id: 'sample-samuel',
                userId: '',
                authorName: 'Samuel',
                createdAt: DateTime.now(),
                content: 'Exemplo',
                likes: 0,
                comments: 0,
                likedByMe: false,
                isSample: true,
              ),
              isAuthenticated: false,
              onRequireLogin: () {},
              onChanged: () async {},
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CircleAvatar));
      await tester.pump();
      expect(
        find.textContaining('Este é um perfil de demonstração'),
        findsOneWidget,
      );
      expect(find.byType(PublicMemberProfileScreen), findsNothing);
      expect(profileRequests, beforeSample);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  tearDownAll(() => Supabase.instance.dispose());
}
