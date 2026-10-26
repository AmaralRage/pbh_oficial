import 'package:flutter/material.dart';

/// Mantém as rotas e seus overlays dentro da mesma largura de celular.
class MobileAppViewport extends StatelessWidget {
  const MobileAppViewport({super.key, required this.child});

  static const double maxWidth = 430;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.clamp(0.0, maxWidth).toDouble();
      final media = MediaQuery.of(context);
      return ColoredBox(
        color: const Color(0xFF070707),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: ClipRect(
              child: MediaQuery(
                data: media.copyWith(size: Size(width, media.size.height)),
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
