import 'dart:ui_web' as ui_web;
import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../services/supreme_seal_document.dart';
import '../models/profile_achievement.dart';

class SupremeSealArt extends StatefulWidget {
  static Future<void> warmUp() async {}
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
  @override
  State<SupremeSealArt> createState() => _SupremeSealArtState();
}

class _SupremeSealArtState extends State<SupremeSealArt> {
  static int _nextId = 0;
  late final String _viewType = 'pbh-supreme-seal-${_nextId++}';
  web.HTMLIFrameElement? _frame;
  StreamSubscription<web.MessageEvent>? _messages;
  bool _animationReported = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_frame != null) return;
    final frame = web.HTMLIFrameElement()
      ..title = 'Arte original: ${widget.achievement.title}'
      ..setAttribute('sandbox', 'allow-scripts')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.pointerEvents = 'none'
      ..style.height = '100%';
    _frame = frame;
    _messages = web.window.onMessage.listen((event) {
      if (!mounted ||
          _animationReported ||
          !widget.celebrate ||
          event.source != frame.contentWindow ||
          event.data?.dartify() != 'pbh-platinum-start')
        return;
      _animationReported = true;
      widget.onAnimationStarted?.call();
    });
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => frame);
    supremeSealDocument(
      reducedMotion: MediaQuery.disableAnimationsOf(context),
      assetPath: widget.achievement.htmlAsset!,
      celebrate: widget.celebrate,
    ).then((source) {
      if (mounted) frame.srcdoc = source;
    });
  }

  @override
  void dispose() {
    _messages?.cancel();
    _frame?.srcdoc = '';
    _frame?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: HtmlElementView(viewType: _viewType),
    ),
  );
}
