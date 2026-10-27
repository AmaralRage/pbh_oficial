import 'package:flutter/material.dart';

/// Own the controller for the route's full lifetime, including its exit animation.
class TextEntryDialog extends StatefulWidget {
  const TextEntryDialog({
    super.key,
    required this.title,
    required this.initialText,
    required this.maxLength,
    this.description,
    this.hint,
    this.saveLabel = 'Salvar',
  });
  final String title, initialText, saveLabel;
  final String? description, hint;
  final int maxLength;
  @override
  State<TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<TextEntryDialog> {
  late final _controller = TextEditingController(text: widget.initialText);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.description != null) Text(widget.description!),
          TextField(
            controller: _controller,
            maxLength: widget.maxLength,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: widget.hint),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed:
            _controller.text.trim().isEmpty ||
                _controller.text.length > widget.maxLength
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: Text(widget.saveLabel),
      ),
    ],
  );
}
