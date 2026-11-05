import 'dart:async';
import 'package:flutter/material.dart';
import '../models/community_mentions.dart';
import '../services/community_service.dart';

class CommunityMentionSuggestions extends StatefulWidget {
  const CommunityMentionSuggestions({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.service,
    this.maxLength = 2000,
    this.maxHeight = 176,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final CommunityService service;
  final int maxLength;
  final double maxHeight;
  @override
  State<CommunityMentionSuggestions> createState() =>
      _CommunityMentionSuggestionsState();
}

class _CommunityMentionSuggestionsState
    extends State<CommunityMentionSuggestions> {
  Timer? _debounce;
  int _version = 0;
  List<Map<String, dynamic>> _members = [];
  MentionToken? _token;
  String? _message;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.focusNode.addListener(_changed);
  }

  @override
  void dispose() {
    _version++;
    _debounce?.cancel();
    widget.controller.removeListener(_changed);
    widget.focusNode.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    final version = ++_version;
    final token =
        widget.focusNode.hasFocus && widget.controller.selection.isCollapsed
        ? CommunityMentions.atCaret(
            widget.controller.text,
            widget.controller.selection.baseOffset,
          )
        : null;
    _token = token;
    if (mounted)
      setState(() {
        _members = [];
        _message = null;
      });
    if (token == null || token.handle.length < 2) return;
    final account = widget.service.currentUserId;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final members = await widget.service.mentionCandidates(token.handle);
        if (!mounted ||
            version != _version ||
            account != widget.service.currentUserId)
          return;
        setState(() {
          _members = members.take(5).toList();
          _message = members.isEmpty
              ? 'Nenhum membro disponível com esse @usuário.'
              : null;
        });
      } catch (_) {
        if (mounted && version == _version)
          setState(
            () => _message =
                'Não foi possível buscar membros. Você pode continuar escrevendo.',
          );
      }
    });
  }

  void _select(Map<String, dynamic> member) {
    final token = _token;
    final handle = member['handle'] as String?;
    if (token == null ||
        handle == null ||
        token.end > widget.controller.text.length)
      return;
    final replacement = '@$handle ';
    final text = widget.controller.text.replaceRange(
      token.start,
      token.end,
      replacement,
    );
    if (text.length > widget.maxLength) {
      setState(() => _message = 'Essa menção ultrapassa o limite do texto.');
      return;
    }
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: token.start + replacement.length,
      ),
    );
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_members.isEmpty && _message == null) return const SizedBox.shrink();
    return TextFieldTapRegion(
      child: Card(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_message!),
                ),
              for (final member in _members)
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: Text(member['name'] as String? ?? 'Membro'),
                  subtitle: Text('@${member['handle']}'),
                  onTap: () => _select(member),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
