import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/community_mentions.dart';
import '../screens/public_member_profile_screen.dart';
import '../services/community_service.dart';

class CommunityMentionText extends StatefulWidget {
  const CommunityMentionText(this.text, {super.key, this.style, this.service});
  final String text;
  final TextStyle? style;
  final CommunityService? service;
  @override
  State<CommunityMentionText> createState() => _CommunityMentionTextState();
}

class _CommunityMentionTextState extends State<CommunityMentionText> {
  late final _service = widget.service ?? CommunityService();
  List<MentionToken> _mentions = [];
  final _gestures = <TapGestureRecognizer>[];
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant CommunityMentionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _prepare();
  }

  void _prepare() {
    for (final gesture in _gestures) {
      gesture.dispose();
    }
    _gestures.clear();
    _mentions = CommunityMentions.inText(widget.text);
    for (final mention in _mentions) {
      _gestures.add(
        TapGestureRecognizer()..onTap = () => _open(mention.handle),
      );
    }
  }

  Future<void> _open(String handle) async {
    if (_opening) return;
    _opening = true;
    try {
      final user = await _service.resolveMention(handle);
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esse perfil não está disponível.')),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PublicMemberProfileScreen(userId: user),
          ),
        );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o perfil. Tente novamente.'),
          ),
        );
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    for (final gesture in _gestures) {
      gesture.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mentions.isEmpty) return Text(widget.text, style: widget.style);
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (var i = 0; i < _mentions.length; i++) {
      final mention = _mentions[i];
      spans.add(TextSpan(text: widget.text.substring(cursor, mention.start)));
      spans.add(
        TextSpan(
          text: widget.text.substring(mention.start, mention.end),
          recognizer: _gestures[i],
          style: TextStyle(
            color: context.pbhColors.orange,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      );
      cursor = mention.end;
    }
    spans.add(TextSpan(text: widget.text.substring(cursor)));
    return Text.rich(TextSpan(children: spans), style: widget.style);
  }
}
