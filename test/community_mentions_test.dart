import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/community_mentions.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/widgets/community_mention_suggestions.dart';
import 'package:pbh_oficial/widgets/community_mention_text.dart';

class _MentionsService extends CommunityService {
  _MentionsService(SupabaseClient client) : super(client: client);
  final searches = <String>[], resolutions = <String>[];
  @override
  String? get currentUserId => 'owner';
  @override
  Future<List<Map<String, dynamic>>> mentionCandidates(String query) async {
    searches.add(query);
    return [
      {'user_id': 'actor', 'name': 'Arthur Morgan', 'handle': 'arthur_morgan'},
    ];
  }

  @override
  Future<String?> resolveMention(String handle) async {
    resolutions.add(handle);
    return null;
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
  test('mentions exclude email addresses, malformed and overlong handles', () {
    expect(
      CommunityMentions.inText(
        'oi @The_Arthur, @reader_user. a@arthur_user.com @@bad @ab',
      ).map((m) => m.handle),
      ['the_arthur', 'reader_user'],
    );
    expect(CommunityMentions.inText('@${'a' * 41}'), isEmpty);
    expect(CommunityMentions.atCaret('email@arthur', 12), isNull);
    expect(CommunityMentions.atCaret('Oi @ar', 6)?.handle, 'ar');
  });
  testWidgets(
    'suggestions insert the handle at the caret without removing the message',
    (tester) async {
      final service = _MentionsService(client),
          controller = TextEditingController(),
          focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: controller, focusNode: focus),
                CommunityMentionSuggestions(
                  controller: controller,
                  focusNode: focus,
                  service: service,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Bom dia @ar');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(service.searches, ['ar']);
      await tester.tap(find.text('Arthur Morgan'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Bom dia @arthur_morgan ');
      expect(controller.selection.baseOffset, controller.text.length);
      expect(find.text('Arthur Morgan'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mention taps resolve the current handle and unavailable profiles stay private',
    (tester) async {
      final service = _MentionsService(client);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityMentionText('Olá @Arthur_Morgan', service: service),
          ),
        ),
      );
      final rich = find.descendant(
        of: find.byType(CommunityMentionText),
        matching: find.byType(RichText),
      );
      final paragraph = tester.renderObject<RenderParagraph>(rich);
      final box = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 4, extentOffset: 18),
          )
          .first;
      await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
      await tester.pumpAndSettle();
      expect(service.resolutions, ['arthur_morgan']);
      expect(find.text('Esse perfil não está disponível.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
