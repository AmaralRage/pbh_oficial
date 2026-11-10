import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ChatPhotoPreviewScreen extends StatefulWidget {
  const ChatPhotoPreviewScreen({
    super.key,
    required this.bytes,
    this.caption = '',
  });
  final Uint8List bytes;
  final String caption;
  @override
  State<ChatPhotoPreviewScreen> createState() => _ChatPhotoPreviewScreenState();
}

class _ChatPhotoPreviewScreenState extends State<ChatPhotoPreviewScreen> {
  late final _caption = TextEditingController(text: widget.caption);
  bool _confirmed = false;
  void _send() {
    if (_confirmed) return;
    setState(() => _confirmed = true);
    Navigator.pop(context, _caption.text);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pbhColors;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.memory(
                    widget.bytes,
                    fit: BoxFit.contain,
                    semanticLabel: 'Foto selecionada para envio',
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 36),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Cancelar envio',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: .55),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Prévia da foto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0xDD000000),
                      Colors.black,
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _caption,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.35,
                        ),
                        cursorColor: colors.orange,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => currentLength < 1800
                            ? null
                            : Text(
                                '$currentLength/$maxLength',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                        decoration: InputDecoration(
                          hintText: 'Adicione uma legenda…',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color.alphaBlend(
                            colors.surface.withValues(alpha: .94),
                            Colors.black,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color: colors.orange,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      tooltip: 'Enviar foto',
                      onPressed: _confirmed ? null : _send,
                      icon: const Icon(Icons.send_rounded, size: 25),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(56, 56),
                        backgroundColor: colors.orange,
                        foregroundColor: colors.orange.computeLuminance() > .179
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
