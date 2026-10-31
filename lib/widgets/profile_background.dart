import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../core/theme/app_colors.dart';
import '../models/profile_style.dart';

/// A static viewport background: it never changes the cover, frame or card fills.
class ProfileBackground extends StatelessWidget {
  const ProfileBackground({
    super.key,
    required this.style,
    required this.child,
    this.bytes,
  });
  final ProfileStyle style;
  final Widget child;
  final Uint8List? bytes;
  @override
  Widget build(BuildContext context) {
    final selected = ProfileStyle.safeBackground(style.background);
    if (selected == 'none') return child;
    final custom = selected == 'custom';
    final path = ProfileStyle.safeBackgroundPath(style.backgroundPath);
    final ImageProvider? image = !custom
        ? null
        : bytes != null
        ? MemoryImage(bytes!)
        : path.isNotEmpty
        ? NetworkImage(
            '${SupabaseConfig.url}/storage/v1/object/public/profile-backgrounds/$path',
          )
        : null;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: context.pbhColors.background),
                  if (!custom) CustomPaint(painter: _BackgroundArt(selected)),
                  if (image != null)
                    Image(
                      image: image,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ColoredBox(
                    color: Colors.black.withValues(
                      alpha: ProfileStyle.safeBackgroundDim(
                        style.backgroundDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Own-account background reacts immediately after saving the profile.
class AccountProfileBackground extends StatelessWidget {
  const AccountProfileBackground({
    super.key,
    required this.child,
    required this.enabled,
  });
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (_, __) => ProfileBackground(
      style: enabled
          ? ProfileStyle.fromMetadata(
              Supabase.instance.client.auth.currentUser?.userMetadata ?? {},
            )
          : const ProfileStyle(),
      child: child,
    ),
  );
}

class _BackgroundArt extends CustomPainter {
  const _BackgroundArt(this.kind);
  final String kind;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final astral = kind == 'astral';
    final library = kind == 'library';
    final accent = astral
        ? const Color(0xFF7757DE)
        : library
        ? const Color(0xFF9D693A)
        : const Color(0xFFE65C21);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.9, -.4),
          radius: 1.4,
          colors: [accent.withValues(alpha: .38), const Color(0xFF08090E)],
        ).createShader(rect),
    );
    final random = math.Random(431);
    if (library) {
      final shelfPaint = Paint()
        ..color = accent.withValues(alpha: .32)
        ..strokeWidth = 3;
      for (double y = 70; y < size.height; y += 125) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), shelfPaint);
        for (double x = 4; x < size.width; x += 15) {
          final height = 40 + random.nextDouble() * 60;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                x,
                y - height,
                7 + random.nextDouble() * 5,
                height - 3,
              ),
              const Radius.circular(1),
            ),
            Paint()
              ..color = accent.withValues(
                alpha: .08 + random.nextDouble() * .13,
              ),
          );
        }
      }
    } else {
      final count = (size.width * size.height / 2500).round().clamp(30, 350);
      for (var i = 0; i < count; i++) {
        canvas.drawCircle(
          Offset(
            random.nextDouble() * size.width,
            random.nextDouble() * size.height,
          ),
          .4 + random.nextDouble() * 1.2,
          Paint()
            ..color = (astral ? Colors.white : accent).withValues(
              alpha: .15 + random.nextDouble() * .4,
            ),
        );
      }
      if (!astral) {
        for (var i = 0; i < 5; i++) {
          final path = Path()
            ..moveTo(-30, size.height * .35 + i * 35)
            ..cubicTo(
              size.width * .7,
              size.height * .1,
              size.width * .2,
              size.height * .9,
              size.width + 30,
              size.height * .75 + i * 20,
            );
          canvas.drawPath(
            path,
            Paint()
              ..color = accent.withValues(alpha: .16)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundArt oldDelegate) =>
      kind != oldDelegate.kind;
}
