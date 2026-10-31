import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/community_draft_store.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/models/community_photo.dart';
import 'package:pbh_oficial/screens/community_post_composer.dart';
import 'package:pbh_oficial/services/community_draft_storage_native.dart'
    as native;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const owner = 'ad300000-0000-4000-8000-000000000001';

class _Service extends CommunityService {
  _Service(SupabaseClient client) : super(client: client);
  @override
  String? get currentUserId => owner;
  @override
  Stream<AuthState> get authChanges => const Stream.empty();
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  test(
    'native draft replacement preserves the latest file and removes it on discard',
    () async {
      final previous = PathProviderPlatform.instance;
      final root = await Directory(
        'build/draft-native-${DateTime.now().microsecondsSinceEpoch}',
      ).create(recursive: true);
      PathProviderPlatform.instance = _Paths(root.absolute.path);
      try {
        await native.writeDraft('owner', 'first');
        await native.writeDraft('owner', 'second');
        expect(await native.readDraft('owner'), 'second');
        await native.removeDraft('owner');
        expect(await native.readDraft('owner'), isNull);
      } finally {
        PathProviderPlatform.instance = previous;
        final buildRoot =
            '${await Directory('build').resolveSymbolicLinks()}${Platform.pathSeparator}';
        final resolved = await root.resolveSymbolicLinks();
        if (!resolved.toLowerCase().startsWith(buildRoot.toLowerCase()))
          throw StateError('Unexpected test directory.');
        await root.delete(recursive: true);
      }
    },
  );
  late Map<String, String> files;
  late CommunityDraftStore store;
  late SupabaseClient client;
  setUp(() {
    files = {};
    store = CommunityDraftStore(
      read: (key) async => files[key],
      write: (key, value) async {
        files[key] = value;
      },
      remove: (key) async {
        files.remove(key);
      },
    );
    client = SupabaseClient(
      'https://test.supabase.co',
      'public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() => client.dispose());
  final photo = CommunityPhoto(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  CommunityDraft draft() => CommunityDraft(
    id: CommunityService.newPostId(),
    text: 'Meu relato salvo',
    tag: 'Vitória',
    topic: 'proposito',
    photos: [photo],
  );
  test(
    'draft retains original attachment bytes and is separated by account',
    () async {
      final value = draft();
      await store.save(owner, value);
      expect(await store.load('another-account'), isNull);
      final restored = await store.load(owner);
      expect(restored!.id, value.id);
      expect(restored.photos.single.bytes, photo.bytes);
      await store.clear(owner);
      expect(await store.load(owner), isNull);
    },
  );
  testWidgets(
    'composer restores text and attachments and autosaves subsequent edits',
    (tester) async {
      final value = draft();
      await store.save(owner, value);
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityPostComposer(
            service: _Service(client),
            draftStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Meu relato salvo'), findsOneWidget);
      expect(find.text('Rascunho recuperado deste aparelho.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Relato atualizado',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      final updated = await store.load(owner);
      expect(updated!.text, 'Relato atualizado');
      expect(updated.id, value.id);
      expect(updated.photos.length, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
