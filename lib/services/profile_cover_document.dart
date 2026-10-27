import 'dart:convert';
import 'dart:typed_data';

/// HTML covers are self-contained art, never pages hosted in the app's origin.
class ProfileCoverDocument {
  static const maxBytes = 5 * 1024 * 1024;
  static bool isHtmlUrl(String? url) => RegExp(
    r'\.html?$',
    caseSensitive: false,
  ).hasMatch(Uri.tryParse(url ?? '')?.path ?? '');
  static bool looksLikeHtml(Uint8List bytes) {
    final prefix = utf8
        .decode(bytes.take(256).toList(), allowMalformed: true)
        .replaceFirst('\uFEFF', '')
        .trimLeft();
    return RegExp(
      r'^<(?:!doctype\s+html|html)\b',
      caseSensitive: false,
    ).hasMatch(prefix);
  }

  static String decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes || !looksLikeHtml(bytes)) {
      throw ArgumentError(
        'Escolha um documento HTML completo, em UTF-8, de até 5 MB.',
      );
    }
    try {
      return utf8.decode(bytes).replaceFirst('\uFEFF', '');
    } on FormatException {
      throw ArgumentError('Salve a arte HTML com codificação UTF-8.');
    }
  }

  static String wrap(
    String source, {
    required bool playing,
    required bool reducedMotion,
  }) {
    final prefix =
        '''<!doctype html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; media-src 'none'; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style id="pbh-cover-play">${playing ? '' : '*{animation-play-state:paused!important}'}</style>
<script>${_playback.replaceAll('%PAUSED%', playing ? 'false' : 'true')}</script>
<style>html,body{margin:0!important;padding:0!important;width:100%!important;height:100%!important;overflow:hidden!important}*{pointer-events:none!important}${reducedMotion ? '*{animation:none!important;transition:none!important}' : ''}</style>
</head><body>''';
    final document = '$prefix$source<script>$_fit</script></body></html>';
    final escaped = const HtmlEscape().convert(document);
    // The outer document's frame-src also prevents navigation of the inner frame
    // to an external page. Neither sandbox grants same-origin, forms or popups.
    return '''<!doctype html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; frame-src 'self' data: blob:; connect-src 'none'; base-uri 'none'; form-action 'none'">
<style>html,body,iframe{margin:0;padding:0;border:0;width:100%;height:100%;overflow:hidden;background:transparent}iframe{pointer-events:none}</style></head><body>
<iframe id="pbh-cover-content" sandbox="allow-scripts" referrerpolicy="no-referrer" srcdoc="$escaped"></iframe>
<script>addEventListener('message',e=>{if(e.source===parent&&(e.data==='pbh-cover:play'||e.data==='pbh-cover:pause'))document.getElementById('pbh-cover-content').contentWindow.postMessage(e.data,'*')});</script>
</body></html>''';
  }

  static const _playback = r'''
(()=>{let paused=%PAUSED%,painted=false,seq=0;const jobs=new Map(),raf=requestAnimationFrame.bind(window),cancel=cancelAnimationFrame.bind(window);
function schedule(id){const job=jobs.get(id);if(!job)return;job.ticket=raf(t=>{job.ticket=null;if(paused&&painted)return;jobs.delete(id);painted=true;job.cb(t)})}
window.requestAnimationFrame=cb=>{const id=++seq;jobs.set(id,{cb,ticket:null});if(!paused||!painted)schedule(id);return id};
window.cancelAnimationFrame=id=>{const job=jobs.get(id);if(job&&job.ticket!==null)cancel(job.ticket);jobs.delete(id)};
addEventListener('message',e=>{if(e.source!==parent)return;if(e.data!=='pbh-cover:play'&&e.data!=='pbh-cover:pause')return;paused=e.data==='pbh-cover:pause';const style=document.getElementById('pbh-cover-play');if(style)style.textContent=paused?'*{animation-play-state:paused!important}':'';for(const [id,job]of jobs){if(job.ticket!==null){cancel(job.ticket);job.ticket=null}if(!paused)schedule(id)}});
})();
''';
  static const _fit = r'''
(()=>{function fit(){const target=document.querySelector('[data-pbh-cover],.pbh-cover,#cover,.cover,#banner,.banner,.stage,body>svg');if(!target)return;for(const style of document.querySelectorAll('style'))document.head.append(style);document.body.replaceChildren(target);for(const [key,value] of Object.entries({position:'relative',width:'100vw',height:'100vh',minHeight:'0',maxHeight:'none',minWidth:'0',maxWidth:'none',margin:'0',border:'0',borderRadius:'0',aspectRatio:'auto',overflow:'hidden'}))target.style.setProperty(key.replace(/[A-Z]/g,c=>'-'+c.toLowerCase()),value,'important');document.body.style.setProperty('display','block','important');dispatchEvent(new Event('resize'))}if(document.readyState==='loading')addEventListener('DOMContentLoaded',fit,{once:true});else fit()})();
''';
}
