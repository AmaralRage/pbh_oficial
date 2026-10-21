import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/supreme_seal_document.dart';
import '../models/profile_achievement.dart';
import 'supreme_seal_art_stub.dart' as fallback;

class SupremeSealArt extends StatefulWidget {
  const SupremeSealArt({
    super.key,
    required this.size,
    required this.achievement,
  });
  final double size;
  final ProfileAchievement achievement;
  @override
  State<SupremeSealArt> createState() => _SupremeSealArtState();
}

class _SupremeSealArtState extends State<SupremeSealArt> {
  WebViewController? _controller;
  bool _failed = false;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !(Platform.isAndroid || Platform.isIOS)) return;
    _started = true;
    _load(MediaQuery.disableAnimationsOf(context));
  }

  Future<void> _load(bool reducedMotion) async {
    try {
      final source = await supremeSealDocument(
        reducedMotion: reducedMotion,
        assetPath: widget.achievement.htmlAsset!,
      );
      if (!mounted) return;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFF030108));
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _failed = true);
            }
          },
        ),
      );
      await controller.loadHtmlString(source);
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || !(Platform.isAndroid || Platform.isIOS)) {
      return fallback.SupremeSealArt(
        size: widget.size,
        achievement: widget.achievement,
      );
    }
    return SizedBox.square(
      dimension: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _controller == null
            ? Center(
                child: CircularProgressIndicator(color: widget.achievement.color),
              )
            : Semantics(
                label: 'Arte animada original: ${widget.achievement.title}',
                child: WebViewWidget(controller: _controller!),
              ),
      ),
    );
  }
}
