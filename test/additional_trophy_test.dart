import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/services/supreme_seal_document.dart';

List<ProfileAchievement> earned({int count = 0, Set<String> ids = const {}}) =>
    ProfileAchievement.earned(
      isAuthenticated: true,
      isProjectLeader: false,
      streak: 0,
      completedChallenges: count,
      totalChallenges: 57,
      followers: 0,
      completedIds: ids,
    );

Future<void> verifyArt(ProfileAchievement badge) async {
  final data = await rootBundle.load(badge.artAsset!);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  final frame = await codec.getNextFrame();
  expect(frame.image.width, 600);
  frame.image.dispose();
  codec.dispose();
  final html = await supremeSealDocument(
    reducedMotion: false,
    assetPath: badge.htmlAsset!,
  );
  expect(html, contains('<svg'));
  expect(html, isNot(contains('<section class="card">')));
  expect(badge.artCaption, isNotNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('early riser art requires completing wake_5', () async {
    expect(earned().any((b) => b.id == 'wake_5'), isFalse);
    expect(
      earned(ids: {'daily_reading'}).any((b) => b.id == 'wake_5'),
      isFalse,
    );
    final badge = earned(ids: {'wake_5'}).single;
    expect(
      badge.htmlAsset,
      'assets/images/Trofeu_madrugador_rosa_perola_mar_PBH.html',
    );
    await verifyArt(badge);
  });
  test('avid reader art requires completing daily_reading', () async {
    expect(earned().any((b) => b.id == 'daily_reading'), isFalse);
    expect(
      earned(ids: {'digital_fast'}).any((b) => b.id == 'daily_reading'),
      isFalse,
    );
    final badge = earned(ids: {'daily_reading'}).single;
    expect(
      badge.htmlAsset,
      'assets/images/Trofeu_leitor_assiduo_esmeralda_PBH.html',
    );
    await verifyArt(badge);
  });
  test('unshakable focus art requires completing digital_fast', () async {
    expect(earned().any((b) => b.id == 'digital_fast'), isFalse);
    expect(
      earned(ids: {'iron_body'}).any((b) => b.id == 'digital_fast'),
      isFalse,
    );
    final badge = earned(ids: {'digital_fast'}).single;
    expect(
      badge.htmlAsset,
      'assets/images/Trofeu_foco_inabalavel_ametista_PBH_universo.html',
    );
    await verifyArt(badge);
  });
  test('iron body art is earned only by completing iron_body', () async {
    expect(earned().any((b) => b.id == 'iron_body'), isFalse);
    expect(
      earned(ids: {'digital_fast'}).any((b) => b.id == 'iron_body'),
      isFalse,
    );
    final badge = earned(ids: {'iron_body'}).single;
    expect(
      badge.htmlAsset,
      'assets/images/Trofeu_corpo_de_ferro_PBH_pulso_reforcado.html',
    );
    await verifyArt(badge);
  });
  test('50 challenges artwork requires at least 50 completions', () async {
    expect(
      earned(
        count: 49,
      ).any((b) => b.htmlAsset == ProfileAchievement.challenges50.htmlAsset),
      isFalse,
    );
    for (final count in [50, 57]) {
      expect(
        earned(count: count).where((b) => b.id == 'challenges').single,
        ProfileAchievement.challenges50,
      );
    }
    await verifyArt(ProfileAchievement.challenges50);
  });
}
