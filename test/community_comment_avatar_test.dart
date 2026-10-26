import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/widgets/community_comment_avatar.dart';

void main() {
  testWidgets(
    'founder uses the profile default only when no uploaded photo exists',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommunityCommentAvatar(name: 'Nome alterado', founder: true),
        ),
      );
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        const AssetImage('assets/images/perfil.png'),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: CommunityCommentAvatar(
            name: 'Nome alterado',
            founder: true,
            avatarUrl: 'https://example.com/new.png',
          ),
        ),
      );
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<NetworkImage>(),
      );
    },
  );
  Widget app(String name, String? url) => MaterialApp(
    home: Scaffold(
      body: CommunityCommentAvatar(name: name, avatarUrl: url),
    ),
  );
  testWidgets(
    'real profile URL wins for names that previously used fixed assets',
    (tester) async {
      for (final name in [
        'Amaral',
        'Samuel',
        'Wellerson',
        'Kanye West',
        'Chad',
      ]) {
        await tester.pumpWidget(app(name, 'https://example.com/current.png'));
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, isA<NetworkImage>());
        expect(
          (image.image as NetworkImage).url,
          'https://example.com/current.png',
        );
        expect(image.image, isNot(isA<AssetImage>()));
      }
    },
  );
  testWidgets(
    'changing or removing the profile photo replaces the old comment image',
    (tester) async {
      await tester.pumpWidget(app('Amaral', 'https://example.com/old.png'));
      await tester.pumpWidget(app('Amaral', 'https://example.com/new.png'));
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, 'https://example.com/new.png');
      expect(image.key, const ValueKey('https://example.com/new.png'));
      expect(image.gaplessPlayback, isFalse);
      await tester.pumpWidget(app('Amaral', null));
      expect(find.byType(Image), findsNothing);
      expect(find.text('A'), findsOneWidget);
    },
  );
}
