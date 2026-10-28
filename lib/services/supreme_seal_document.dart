import 'package:flutter/services.dart';

final _documents = <(String, bool, bool, bool), Future<String>>{};

Future<String> supremeSealDocument({
  required bool reducedMotion,
  bool mobileRendering = false,
  bool celebrate = false,
  String assetPath = 'assets/images/Troféu supremo PBH.html',
}) => celebrate
    // Rebuild the playback bridge after hot reload or an asset update. Keeping
    // a previously prepared celebration can leave the new sound callback silent.
    ? _prepareDocument(assetPath, reducedMotion, mobileRendering, celebrate)
    : _documents.putIfAbsent(
        (assetPath, reducedMotion, mobileRendering, celebrate),
        () => _prepareDocument(
          assetPath,
          reducedMotion,
          mobileRendering,
          celebrate,
        ),
      );

Future<String> _prepareDocument(
  String assetPath,
  bool reducedMotion,
  bool mobileRendering,
  bool celebrate,
) async {
  var html = await rootBundle.loadString(assetPath);
  if (assetPath == 'assets/images/Trofeu_Platina_PBH.html') {
    html = html.replaceAll(
      RegExp(r'<div class="controls">[\s\S]*?</div>'),
      celebrate && !reducedMotion
          ? '<button id="replay" hidden></button><input id="sound" type="checkbox" hidden>'
          : '',
    );
    if (!celebrate || reducedMotion) {
      // Keep SVG construction and its ambient animations; omit the one-shot
      // reveal, flash, audio and canvas burst during regular profile viewing.
      html = html.replaceFirst(
        RegExp(r'// Partículas, ondas e som originais[\s\S]*?</script>'),
        '</script>',
      );
      html = html.replaceAll(
        RegExp(r'<canvas class="fx"[^>]*></canvas>|<div class="flash"></div>'),
        '',
      );
    } else {
      html = html.replaceFirst(
        'if(elapsed<5.2)raf=requestAnimationFrame(draw)',
        "if(elapsed<5.2)raf=requestAnimationFrame(draw);else{ctx.clearRect(0,0,600,600);stage.classList.remove('playing')}",
      );
    }
  }
  html = html.replaceFirst(
    '<html lang="pt-BR">',
    '<html lang="pt-BR" data-theme="dark">',
  );
  // Preserve the supplied SVG and animation scripts; the app renders the text.
  html = html.replaceAll(
    RegExp(r'<section class="card">[\s\S]*?</section>'),
    '',
  );
  if (mobileRendering) {
    // Lower only procedural texture detail, keeping every animation and glow.
    html = html.replaceAll('numOctaves="4"', 'numOctaves="2"');
    html = html.replaceFirst(
      '</head>',
      '<style id="pbh-playback">*{animation-play-state:paused!important}</style></head>',
    );
  }
  html = html.replaceAll(
    RegExp(r'<link[^>]+href="https://fonts\.googleapis\.com[^>]*>'),
    '',
  );
  if (celebrate &&
      !reducedMotion &&
      assetPath == 'assets/images/Trofeu_Platina_PBH.html') {
    html = html.replaceFirst('</head>', '''<script>
    (()=>{let reported=false;document.addEventListener('animationstart',event=>{
      if(reported||event.animationName!=='revealBadge')return;
      reported=true;
      if(window.PbhPlatinumStarted)window.PbhPlatinumStarted.postMessage('started');
      else parent.postMessage('pbh-platinum-start','*');
    })})();
    </script></head>''');
  }
  return html.replaceFirst('</head>', '''<style>
    html,body{padding:0!important;margin:0!important;overflow:hidden;background:#030108}
    main{max-width:none;width:100%}.stage{border-radius:0;box-shadow:none;contain:layout paint}
    ${reducedMotion ? '*{animation:none!important}' : ''}
    </style></head>''');
}
