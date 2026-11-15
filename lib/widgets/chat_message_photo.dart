import 'package:flutter/material.dart';

/// Uses the decoded image's aspect ratio, without cropping the attachment.
class ChatMessagePhoto extends StatelessWidget {
  const ChatMessagePhoto({super.key, required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: 240,
      maxHeight: (MediaQuery.sizeOf(context).height * .38).clamp(200, 300),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image(
        image: image,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, synchronous) =>
            frame != null || synchronous
            ? child
            : const SizedBox(
                width: 220,
                height: 160,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 160,
          height: 100,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    ),
  );
}
