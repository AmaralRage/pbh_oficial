import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/profile_achievement.dart';
import '../services/supreme_seal_document.dart';
import 'supreme_seal_art_stub.dart' as fallback;

// Retain one browser controller, never one per badge. The idle document is paused.
Future<WebViewController>? _idleController;
Future<WebViewController> _createController() async {
  final controller = WebViewController();
  await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
  await controller.setBackgroundColor(const Color(0xFF030108));
  return controller;
}

Future<void> _warmUp() async {
  if (!(Platform.isAndroid || Platform.isIOS) || _idleController != null)
    return;
  final pending = _createController();
  _idleController = pending;
  try {
    await pending;
  } catch (_) {
    if (identical(_idleController, pending)) _idleController = null;
  }
}

class SupremeSealArt extends StatefulWidget {
  const SupremeSealArt({
    super.key,
    required this.size,
    required this.achievement,
    this.celebrate = false,
    this.onAnimationStarted,
  });
  final double size;
  final bool celebrate;
  final VoidCallback? onAnimationStarted;
  final ProfileAchievement achievement;
  static Future<void> warmUp() => _warmUp();
  @override
  State<SupremeSealArt> createState() => _SupremeSealArtState();
}

class _SupremeSealArtState extends State<SupremeSealArt>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _started = false;
  bool _ready = false;
  bool _failed = false;
  bool _animationReported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !(Platform.isAndroid || Platform.isIOS)) return;
    _started = true;
    _load(MediaQuery.disableAnimationsOf(context));
  }

  Future<void> _load(bool reduced) async {
    WebViewController? acquired;
    try {
      final pending = _idleController;
      _idleController = null;
      acquired = await (pending ?? _createController());
      if (!mounted) {
        await _release(acquired);
        return;
      }
      _controller = acquired;
      await acquired.addJavaScriptChannel(
        'PbhPlatinumStarted',
        onMessageReceived: (_) {
          if (!mounted || !widget.celebrate || _animationReported || reduced)
            return;
          _animationReported = true;
          widget.onAnimationStarted?.call();
        },
      );
      final source = await supremeSealDocument(
        reducedMotion: reduced,
        mobileRendering: true,
        assetPath: widget.achievement.htmlAsset!,
        celebrate: widget.celebrate,
      );
      if (!mounted) return;
      await acquired.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _ready = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                _play(
                  WidgetsBinding.instance.lifecycleState == null ||
                      WidgetsBinding.instance.lifecycleState ==
                          AppLifecycleState.resumed,
                );
            });
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _failed = true);
            }
          },
        ),
      );
      if (!mounted) return;
      await acquired.loadHtmlString(source);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _play(bool play) async {
    if (!_ready) return;
    try {
      await _controller?.runJavaScript(
        "document.getElementById('pbh-playback').textContent = ${play ? "''" : "'*{animation-play-state:paused!important}'"};",
      );
    } catch (_) {
      /* A closing view may already be detached. */
    }
  }

  Future<void> _release(WebViewController controller) async {
    try {
      await controller.removeJavaScriptChannel('PbhPlatinumStarted');
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.prevent,
        ),
      );
      await controller.runJavaScript(
        "var s=document.getElementById('pbh-playback');if(s)s.textContent='*{animation-play-state:paused!important}';",
      );
      if (_idleController == null) {
        _idleController = Future.value(controller);
      } else {
        await controller.loadHtmlString('<html></html>');
      }
    } catch (_) {
      /* Drop an invalid controller instead of caching it. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _play(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) _release(controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = fallback.SupremeSealArt(
      size: widget.size,
      achievement: widget.achievement,
    );
    if (_failed || !(Platform.isAndroid || Platform.isIOS)) return preview;
    return SizedBox.square(
      dimension: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (!_ready) IgnorePointer(child: preview),
          ],
        ),
      ),
    );
  }
}
