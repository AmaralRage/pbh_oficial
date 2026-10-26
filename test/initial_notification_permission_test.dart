import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pbh_oficial/services/initial_notification_permission.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  for (final allowed in [true, false]) {
    test(
      'first launch stores decision $allowed and never asks again',
      () async {
        var prompts = 0;
        Future<bool> request() async {
          prompts++;
          return allowed;
        }

        await InitialNotificationPermission().requestOnce(request);
        await InitialNotificationPermission().requestOnce(request);
        expect(prompts, 1);
        expect(
          await SharedPreferencesAsync().getBool(
            InitialNotificationPermission.enabledKey,
          ),
          allowed,
        );
      },
    );
  }
  test('explicit disable is preserved without a permission prompt', () async {
    await SharedPreferencesAsync().setBool(
      InitialNotificationPermission.enabledKey,
      false,
    );
    await InitialNotificationPermission().requestOnce(
      () async => fail('Must not prompt'),
    );
  });
  test('interrupted permission request is not repeated on restart', () async {
    await expectLater(
      InitialNotificationPermission().requestOnce(
        () async => throw StateError('closed'),
      ),
      throwsStateError,
    );
    await InitialNotificationPermission().requestOnce(
      () async => fail('Must not prompt again'),
    );
  });
}
