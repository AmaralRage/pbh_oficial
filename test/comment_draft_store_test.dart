import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pbh_oficial/services/comment_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'comment drafts survive recreation and stay isolated by account and post',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await CommentDraftStore().save('a', 'post1', 'My unfinished reply');
      final next = CommentDraftStore();
      expect(await next.load('a', 'post1'), 'My unfinished reply');
      expect(await next.load('b', 'post1'), isNull);
      expect(await next.load('a', 'post2'), isNull);
      await next.save('a', 'post1', '');
      expect(await next.load('a', 'post1'), isNull);
    },
  );
}
