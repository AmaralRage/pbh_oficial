import 'package:flutter/material.dart';

class AnimatedEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Offset beginOffset;

  const AnimatedEntry({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.beginOffset = const Offset(0, 0.08),
  });

  @override
  State<AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<AnimatedEntry> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : widget.beginOffset,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
