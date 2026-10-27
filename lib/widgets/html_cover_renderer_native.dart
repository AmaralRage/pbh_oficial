import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'html_cover_renderer_stub.dart' as fallback;

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
  WebViewController? _controller;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) _load();
  }

  Future<void> _load() async {
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.transparent);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url == 'about:blank' || request.url == 'about:srcdoc'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) => _play(),
        ),
      );
      if (!mounted) return;
      _controller = controller;
      await controller.loadHtmlString(widget.document);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _play() async {
    if (!mounted) return;
    try {
      await _controller?.runJavaScript(
        "document.getElementById('pbh-cover-content')?.contentWindow.postMessage('${widget.playing ? 'pbh-cover:play' : 'pbh-cover:pause'}','*')",
      );
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant HtmlCoverRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _controller?.loadHtmlString(widget.document);
    }
    _play();
  }

  @override
  void dispose() {
    _controller?.loadHtmlString('<!doctype html><html></html>');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(Platform.isAndroid || Platform.isIOS))
      return fallback.HtmlCoverRenderer(
        document: widget.document,
        playing: widget.playing,
      );
    if (_failed)
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white54),
      );
    final controller = _controller;
    return controller == null
        ? const SizedBox.shrink()
        : WebViewWidget(controller: controller);
  }
}
