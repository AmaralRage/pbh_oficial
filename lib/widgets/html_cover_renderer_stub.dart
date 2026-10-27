import 'package:flutter/material.dart';

class HtmlCoverRenderer extends StatelessWidget {
  const HtmlCoverRenderer({
    super.key,
    required this.document,
    required this.playing,
  });
  final String document;
  final bool playing;
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Capa HTML disponível no Android, iOS e navegador.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white),
    ),
  );
}
