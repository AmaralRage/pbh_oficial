import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ChatWaveform extends StatelessWidget {
  const ChatWaveform({
    super.key,
    required this.samples,
    required this.progress,
    this.onSeek,
  });
  final List<double> samples;
  final double progress;
  final ValueChanged<double>? onSeek;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      void seek(double x) =>
          onSeek?.call((x / constraints.maxWidth).clamp(0, 1));
      return Semantics(
        label: 'Progresso do áudio',
        value: '${(progress * 100).round()}%',
        increasedValue: '${((progress + .05).clamp(0, 1) * 100).round()}%',
        decreasedValue: '${((progress - .05).clamp(0, 1) * 100).round()}%',
        slider: true,
        onIncrease: onSeek == null
            ? null
            : () => onSeek!((progress + .05).clamp(0, 1)),
        onDecrease: onSeek == null
            ? null
            : () => onSeek!((progress - .05).clamp(0, 1)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSeek == null ? null : (d) => seek(d.localPosition.dx),
          onHorizontalDragUpdate: onSeek == null
              ? null
              : (d) => seek(d.localPosition.dx),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: CustomPaint(
              painter: _WavePainter(
                samples,
                progress,
                context.pbhColors.orange,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.samples, this.progress, this.accent);
  final List<double> samples;
  final double progress;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / 4).floor().clamp(1, 64);
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      var amplitude = 0.0;
      if (samples.isNotEmpty) {
        final start = i * samples.length ~/ count,
            end = math
                .max(start + 1, (i + 1) * samples.length ~/ count)
                .clamp(0, samples.length);
        for (var j = start; j < end; j++) {
          amplitude = math.max(amplitude, samples[j]);
        }
      }
      final height = 3 + amplitude.clamp(0, 1) * 27;
      final x = (i + .5) * size.width / count;
      final played = x <= size.width * progress;
      paint.color = accent.withValues(alpha: played ? 1 : .24);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.samples != samples ||
      old.progress != progress ||
      old.accent != accent;
}
