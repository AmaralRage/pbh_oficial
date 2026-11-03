import 'dart:math' as math;
import 'package:flutter/material.dart';

class CommentLikeIcon extends StatefulWidget {
  const CommentLikeIcon({super.key, required this.liked, required this.color});
  final bool liked;
  final Color color;

  @override
  State<CommentLikeIcon> createState() => _CommentLikeIconState();
}

class _CommentLikeIconState extends State<CommentLikeIcon>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.4,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(tween: Tween(begin: 1.4, end: .94), weight: 35),
    TweenSequenceItem(tween: Tween(begin: .94, end: 1.0), weight: 25),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant CommentLikeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.liked || MediaQuery.disableAnimationsOf(context)) {
      _controller.reset();
    } else if (!oldWidget.liked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: Icon(
      widget.liked
          ? Icons.local_fire_department
          : Icons.local_fire_department_outlined,
      size: 18,
      color: widget.color,
    ),
    builder: (context, child) => Transform.rotate(
      angle: math.sin(_controller.value * math.pi * 2) * .16,
      child: Transform.scale(scale: _scale.value, child: child),
    ),
  );
}
