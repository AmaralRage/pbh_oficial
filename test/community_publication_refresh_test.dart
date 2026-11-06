import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/community_post_model.dart';
import 'package:pbh_oficial/screens/community_screen.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/widgets/community_post_card.dart';
import 'package:pbh_oficial/widgets/connection_notice.dart';

class _Fonts extends AssetManifest {
  @override
  List<String> listAssets() => ['Manrope-Regular.ttf'];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

CommunityPostModel post(String content) => CommunityPostModel(
  id: 'p1',
  userId: 'owner',
  authorName: 'Membro',
  createdAt: DateTime(2026, 11, 5),
  content: content,
  likes: 0,
  comments: 4,
  likedByMe: false,
  isSaved: true,
);

class _Posts extends CommunityService {
  _Posts(superClient) : super(client: superClient);
  int loads = 0;
  bool offline = false;
  final pending = <Completer<CommunityPostModel?>>[];
  @override
  Future<List<CommunityPostModel>> fetchPosts({
    int filterIndex = 0,
    int offset = 0,
    int limit = 20,
    String search = '',
    String? topic,
  }) async {
    loads++;
    if (offline) throw StateError('offline');
    return [post('Texto anterior')];
  }

  @override
  Future<CommunityStats> fetchStats() async =>
      const CommunityStats(posts: 1, comments: 4, likes: 0);
  @override
  Future<CommunityPostModel?> postById(String id) {
    final result = Completer<CommunityPostModel?>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  testWidgets(
    'editing refreshes only its card and ignores stale overlapping responses',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      fonts.assetManifest = _Fonts();
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async =>
            utf8.decode(message!.buffer.asUint8List()) == 'Manrope-Regular.ttf'
            ? ByteData(0)
            : null,
      );
      await tester.runAsync(
        () => Supabase.initialize(
          url: 'https://test.supabase.co',
          publishableKey: 'public-key',
          authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            localStorage: EmptyLocalStorage(),
            detectSessionInUri: false,
          ),
          httpClient: MockClient(
            (request) async => http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );
      addTearDown(() async {
        fonts.assetManifest = null;
        fonts.clearCache();
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        );
        await Supabase.instance.dispose();
      });
      final service = _Posts(Supabase.instance.client);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityScreen(
              service: service,
              isAuthenticated: false,
              onRequireLogin: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(CommunityPostCard),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final card = tester.widget<CommunityPostCard>(
        find.byType(CommunityPostCard),
      );
      final first = card.onPublicationChanged!();
      final second = card.onPublicationChanged!();
      service.pending[1].complete(post('Texto atualizado'));
      await second;
      await tester.pump();
      service.pending[0].complete(post('Resposta antiga'));
      await first;
      await tester.pump();
      expect(service.loads, 1);
      final updated = tester.widget<CommunityPostCard>(
        find.byType(CommunityPostCard),
      );
      expect(updated.post.content, 'Texto atualizado');
      expect(updated.post.comments, 4);
      expect(updated.post.isSaved, true);
      service.offline = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(
        tester
            .widget<CommunityPostCard>(find.byType(CommunityPostCard))
            .post
            .content,
        'Texto atualizado',
      );
      expect(find.byType(ConnectionNotice), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
