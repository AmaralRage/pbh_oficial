import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class HtmlCoverRenderer extends StatefulWidget {
  const HtmlCoverRenderer({
    super.key,
    required this.document,
    required this.playing,
  });
  final String document;
  final bool playing;
  @override
  State<HtmlCoverRenderer> createState() => _HtmlCoverRendererState();
}

class _HtmlCoverRendererState extends State<HtmlCoverRenderer> {
  static int _next = 0;
  late final _viewType = 'pbh-cover-${_next++}';
  late final web.HTMLIFrameElement _frame;
  @override
  void initState() {
    super.initState();
    _frame = web.HTMLIFrameElement()
      ..title = 'Arte da capa do perfil'
      ..setAttribute('sandbox', 'allow-scripts')
      ..referrerPolicy = 'no-referrer'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.pointerEvents = 'none'
      ..srcdoc = widget.document;
    _frame.onLoad.listen((_) {
      if (mounted) _play();
    });
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
  }

  void _play() => _frame.contentWindow?.postMessage(
    (widget.playing ? 'pbh-cover:play' : 'pbh-cover:pause').toJS,
    '*'.toJS,
  );
  @override
  void didUpdateWidget(covariant HtmlCoverRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) _frame.srcdoc = widget.document;
    _play();
  }

  @override
  void dispose() {
    _frame.srcdoc = '';
    _frame.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
