import 'package:flutter/material.dart';

// Framing affects only the preview; the source image remains untouched.
class CommunityFramedImage extends StatelessWidget {
  const CommunityFramedImage({super.key, required this.child, this.framing});
  final Widget child;
  final List<dynamic>? framing;
  @override
  Widget build(BuildContext context) {
    final r = framing;
    if (r == null ||
        r.length != 4 ||
        r.any((v) => v is! num || !v.isFinite) ||
        r[2] <= 0 ||
        r[3] <= 0)
      return child;
    return LayoutBuilder(
      builder: (context, size) => ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: size.maxWidth / r[2],
          maxWidth: size.maxWidth / r[2],
          minHeight: size.maxHeight / r[3],
          maxHeight: size.maxHeight / r[3],
          child: Transform.translate(
            offset: Offset(
              -r[0] * size.maxWidth / r[2],
              -r[1] * size.maxHeight / r[3],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
