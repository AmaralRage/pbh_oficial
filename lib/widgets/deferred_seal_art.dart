import 'package:flutter/material.dart';

/// Keeps platform-view creation out of the dialog's opening transition.
class DeferredSealArt extends StatefulWidget {
  const DeferredSealArt({
    super.key,
    required this.preview,
    required this.builder,
  });

  final Widget preview;
  final Widget Function() builder;

  @override
  State<DeferredSealArt> createState() => _DeferredSealArtState();
}

class _DeferredSealArtState extends State<DeferredSealArt> {
  Animation<double>? _transition;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final transition = ModalRoute.of(context)?.animation;
    if (identical(transition, _transition) && _transition != null) return;
    _transition?.removeStatusListener(_onStatus);
    _transition = transition;
    _ready = transition == null || transition.isCompleted;
    transition?.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (!_ready && status == AnimationStatus.completed && mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _transition?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.builder() : widget.preview;
}
