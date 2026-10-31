import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The official player's platform interface is used to simulate native playback.
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:pbh_oficial/widgets/community_photo_gallery.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  int plays = 0, pauses = 0, disposed = 0;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) async* {
    yield VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 20),
      size: const Size(640, 360),
    );
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed++;
  }

  @override
  Future<void> play(int playerId) async {
    plays++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauses++;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

void main() {
  testWidgets(
    'video requires a tap and pauses on leaving the page or backgrounding',
    (tester) async {
      final previous = VideoPlayerPlatform.instance;
      final platform = _VideoPlatform();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = previous);
      Widget page(bool active) => MaterialApp(
        home: Scaffold(
          body: CommunityVideoPlayer(
            url: 'https://example.invalid/video.mp4',
            active: active,
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(platform.plays, 0);
      await tester.tap(find.byTooltip('Reproduzir vídeo'));
      await tester.pump();
      expect(platform.plays, 1);
      final pauses = platform.pauses;
      await tester.pumpWidget(page(false));
      await tester.pump();
      expect(platform.pauses, greaterThan(pauses));
      await tester.pumpWidget(page(true));
      await tester.pump();
      expect(
        platform.plays,
        1,
      ); // Returning never restarts audio automatically.
      await tester.tap(find.byTooltip('Reproduzir vídeo'));
      await tester.pump();
      final backgroundPauses = platform.pauses;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(platform.pauses, greaterThan(backgroundPauses));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(platform.disposed, 1);
    },
  );
}
