import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/community_photo.dart';
import 'package:pbh_oficial/models/community_post_model.dart';
import 'package:pbh_oficial/screens/community_post_editor.dart';
import 'package:pbh_oficial/services/community_service.dart';

class _EditorService extends CommunityService {
  _EditorService(SupabaseClient client) : super(client: client);
  bool fail = true;
  String? savedText;
  List<String?>? savedPaths;
  @override
  String? get currentUserId => 'owner';
  @override
  Future<void> editPublication(
    CommunityPostModel post,
    String content,
    List<String?> paths,
    List<CommunityPhoto?> photos,
    List<dynamic> framings, {
    void Function(int completed, int total)? onUploadProgress,
  }) async {
    if (fail) throw StateError('offline');
    savedText = content;
    savedPaths = paths;
  }
}

void main() {
  late SupabaseClient client;
  setUp(
    () => client = SupabaseClient(
      'https://test.supabase.co',
      'key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
  tearDown(() => client.dispose());
  CommunityPostModel post() => CommunityPostModel(
    id: 'post',
    userId: 'owner',
    authorName: 'Member',
    createdAt: DateTime.now(),
    content: 'Before',
    likes: 0,
    comments: 0,
    likedByMe: false,
    imagePaths: const ['owner/post/0.jpg'],
  );
  testWidgets(
    'editor retains changes after failure and saves text with attachment removal',
    (tester) async {
      final service = _EditorService(client);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommunityPostEditor(post: post(), service: service),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Enquadrar'), findsOneWidget);
      await tester.tap(find.byTooltip('Remover anexo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'After');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Suas alterações continuam aqui'),
        findsOneWidget,
      );
      expect(find.text('After'), findsOneWidget);
      expect(result, isNull);
      service.fail = false;
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(service.savedText, 'After');
      expect(service.savedPaths, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('back asks before discarding an edited publication', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPostEditor(
          post: post(),
          service: _EditorService(client),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Changed');
    await tester.pump();
    final context = tester.element(find.byType(CommunityPostEditor));
    Navigator.of(context).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Changed'), findsOneWidget);
  });
}
