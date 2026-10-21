import 'package:flutter/services.dart';

final _documents = <(String, bool), Future<String>>{};

Future<String> supremeSealDocument({
  required bool reducedMotion,
  String assetPath = 'assets/images/Troféu supremo PBH.html',
}) => _documents.putIfAbsent((
  assetPath,
  reducedMotion,
), () => _prepareDocument(assetPath, reducedMotion));

Future<String> _prepareDocument(String assetPath, bool reducedMotion) async {
  var html = await rootBundle.loadString(assetPath);
  html = html.replaceFirst(
    '<html lang="pt-BR">',
    '<html lang="pt-BR" data-theme="dark">',
  );
  // Preserve the supplied SVG and animation scripts; the app renders the text.
  html = html.replaceAll(
    RegExp(r'<section class="card">[\s\S]*?</section>'),
    '',
  );
  html = html.replaceAll(
    RegExp(r'<link[^>]+href="https://fonts\.googleapis\.com[^>]*>'),
    '',
  );
  return html.replaceFirst('</head>', '''<style>
    html,body{padding:0!important;margin:0!important;overflow:hidden;background:#030108}
    main{max-width:none;width:100%}.stage{border-radius:0;box-shadow:none}
    ${reducedMotion ? '*{animation:none!important}' : ''}
    </style></head>''');
}
