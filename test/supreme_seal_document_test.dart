import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/services/supreme_seal_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reopening platinum after an asset refresh rebuilds its sound bridge',
    () async {
      const asset = 'assets/images/Trofeu_Platina_PBH.html';
      final original = await rootBundle.loadString(asset);
      var revision = 'first-preview';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final path = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        if (path != asset) return null;
        return ByteData.sublistView(
          Uint8List.fromList(utf8.encode('$original<!--$revision-->')),
        );
      });
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict(asset);
      });
      rootBundle.evict(asset);
      final first = await supremeSealDocument(
        reducedMotion: false,
        celebrate: true,
        assetPath: asset,
      );
      expect(first, contains('first-preview'));
      revision = 'updated-preview';
      rootBundle.evict(asset);
      final updated = await supremeSealDocument(
        reducedMotion: false,
        celebrate: true,
        assetPath: asset,
      );
      expect(updated, contains('updated-preview'));
      expect(updated, contains("parent.postMessage('pbh-platinum-start','*')"));
    },
  );
  test(
    'mobile optimization preserves every trophy animation and script',
    () async {
      final additional = ProfileAchievement.earned(
        isAuthenticated: true,
        isProjectLeader: true,
        streak: 2000,
        completedChallenges: 57,
        totalChallenges: 57,
        followers: 0,
        completedIds: {'iron_body', 'digital_fast', 'daily_reading', 'wake_5'},
      );
      for (final badge in additional.where(
        (badge) => badge.htmlAsset != null && badge.id != 'platinum',
      )) {
        final original = await rootBundle.loadString(badge.htmlAsset!);
        final optimized = await supremeSealDocument(
          reducedMotion: false,
          mobileRendering: true,
          assetPath: badge.htmlAsset!,
        );
        for (final pattern in [
          r'@keyframes\s+[\w-]+',
          r'<script>[\s\S]*?</script>',
        ]) {
          expect(
            RegExp(
              pattern,
            ).allMatches(optimized).map((m) => m.group(0)).toList(),
            RegExp(
              pattern,
            ).allMatches(original).map((m) => m.group(0)).toList(),
            reason: badge.title,
          );
        }
        expect(optimized, contains('id="pbh-playback"'));
        expect(optimized, contains('numOctaves="2"'));
        expect(optimized, contains('feGaussianBlur'));
        // Keep the source's accessibility media query, without disabling motion globally.
        expect(
          RegExp('animation:none!important').allMatches(optimized).length,
          RegExp('animation:none!important').allMatches(original).length,
        );
      }
    },
  );
  test(
    'mobile and web caches keep independent rendering and accessibility settings',
    () async {
      final mobile = await supremeSealDocument(
        reducedMotion: false,
        mobileRendering: true,
      );
      final web = await supremeSealDocument(reducedMotion: false);
      final reduced = await supremeSealDocument(
        reducedMotion: true,
        mobileRendering: true,
      );
      expect(mobile, contains('numOctaves="2"'));
      expect(web, contains('numOctaves="4"'));
      expect(web, isNot(contains('id="pbh-playback"')));
      expect(reduced, contains('*{animation:none!important}'));
    },
  );
  test('every trophy preview asset exists and decodes', () async {
    for (final badge in [
      ...ProfileAchievement.supremeSeals,
      ProfileAchievement.platinum,
      ProfileAchievement.dedication2000,
    ]) {
      final data = await rootBundle.load(badge.artAsset!);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0), reason: badge.id);
      frame.image.dispose();
      codec.dispose();
    }
  });
  test(
    '2000-day amber trophy preserves original flame and animation',
    () async {
      final source = await supremeSealDocument(
        reducedMotion: false,
        assetPath: 'assets/images/Trofeu_2000_completo.html',
      );
      expect(source, contains('2000 dias de dedicação · Troféu Âmbar PBH'));
      expect(source, contains('chama de cristal dourado'));
      expect(source, contains('@keyframes float'));
      expect(source, isNot(contains('<section class="card">')));
    },
  );
  test(
    'platinum art preserves the supplied crystal trophy and animation',
    () async {
      final source = await supremeSealDocument(
        reducedMotion: false,
        assetPath: 'assets/images/Trofeu_Platina_PBH.html',
      );
      expect(source, contains('<title>Troféu de Platina PBH</title>'));
      expect(source, contains('troféu cristalino azul e prata'));
      expect(source, contains('@keyframes sheen'));
      expect(source, isNot(contains('<section class="card">')));
    },
  );
  test(
    'platinum profile animation omits unlock sequence; celebration is opt-in',
    () async {
      const asset = 'assets/images/Trofeu_Platina_PBH.html';
      final normal = await supremeSealDocument(
        reducedMotion: false,
        assetPath: asset,
      );
      final unlock = await supremeSealDocument(
        reducedMotion: false,
        assetPath: asset,
        celebrate: true,
      );
      final reduced = await supremeSealDocument(
        reducedMotion: true,
        assetPath: asset,
        celebrate: true,
      );
      for (final source in [normal, unlock, reduced]) {
        expect(source, contains('var bm=document.getElementById("beams")'));
        expect(source, isNot(contains('<div class="controls">')));
        expect(source, isNot(contains('fonts.googleapis.com')));
      }
      expect(normal, isNot(contains('function play()')));
      expect(normal, isNot(contains('pbh-platinum-start')));
      expect(normal, isNot(contains('<canvas class="fx"')));
      expect(normal, contains('@keyframes float'));
      expect(unlock, contains('function play()'));
      expect(unlock, contains("event.animationName!=='revealBadge'"));
      expect(unlock, contains("parent.postMessage('pbh-platinum-start','*')"));
      expect(unlock, contains('<canvas class="fx"'));
      expect(reduced, isNot(contains('function play()')));
      expect(reduced, isNot(contains('pbh-platinum-start')));
      expect(reduced, contains('*{animation:none!important}'));
      Directory('build').createSync(recursive: true);
      File('build/platinum-profile-verified.html').writeAsStringSync(normal);
      File('build/platinum-unlock-verified.html').writeAsStringSync(unlock);
    },
  );
  test(
    'porn-free art preserves the original crystal and ripple animations',
    () async {
      final source = await supremeSealDocument(
        reducedMotion: false,
        assetPath: 'assets/images/Troféu supremo sem pornô.html',
      );
      expect(source, contains('<title>Troféu supremo sem pornô</title>'));
      expect(source, contains('gota de cristal azul'));
      expect(source, contains('@keyframes rip'));
      expect(source, isNot(contains('<section class="card">')));
    },
  );
  test('reading art preserves the original book and page animations', () async {
    final source = await supremeSealDocument(
      reducedMotion: false,
      assetPath: 'assets/images/Troféu supremo de leitura.html',
    );
    expect(source, contains('<title>Troféu supremo de leitura</title>'));
    expect(source, contains('livro aberto de páginas luminosas'));
    expect(source, contains('@keyframes flip'));
    expect(source, contains('@keyframes runeUp'));
    expect(source, isNot(contains('<section class="card">')));
  });
  test('training art loads its own original HTML and energy effects', () async {
    final source = await supremeSealDocument(
      reducedMotion: false,
      assetPath: 'assets/images/Troféu supremo de treino.html',
    );
    expect(source, contains('<title>Troféu supremo de treino</title>'));
    expect(source, contains('halter de metal vermelho e ouro'));
    expect(source, contains('@keyframes wave'));
    expect(source, isNot(contains('<section class="card">')));
  });
  test(
    'expanded art preserves supplied SVG and scripts without external font requests',
    () async {
      final source = await supremeSealDocument(reducedMotion: false);
      expect(source, contains('<svg viewBox="0 0 600 600"'));
      expect(source, contains('document.getElementById("parts")'));
      expect(source, contains('data-theme="dark"'));
      expect(source, isNot(contains('<section class="card">')));
      expect(source, isNot(contains('href="https://fonts.googleapis.com')));
    },
  );
  test('reduced motion disables the original CSS animations', () async {
    final source = await supremeSealDocument(reducedMotion: true);
    expect(source, contains('*{animation:none!important}'));
  });
}
