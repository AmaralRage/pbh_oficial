class MentionToken {
  const MentionToken(this.start, this.end, this.handle);
  final int start, end;
  final String handle;
}

class CommunityMentions {
  CommunityMentions._();
  static final _word = RegExp(r'[A-Za-z0-9_@.]');
  static final _handle = RegExp(
    r'@([A-Za-z][A-Za-z0-9_]{2,39})(?![A-Za-z0-9_])',
  );
  static List<MentionToken> inText(String text) => [
    for (final match in _handle.allMatches(text))
      if (match.start == 0 || !_word.hasMatch(text[match.start - 1]))
        MentionToken(match.start, match.end, match.group(1)!.toLowerCase()),
  ].take(20).toList();

  static MentionToken? atCaret(String text, int caret) {
    if (caret < 0 || caret > text.length) return null;
    if (caret < text.length && RegExp(r'[A-Za-z0-9_]').hasMatch(text[caret]))
      return null;
    final match = RegExp(
      r'@([A-Za-z][A-Za-z0-9_]{0,39})$',
    ).firstMatch(text.substring(0, caret));
    if (match == null ||
        match.start > 0 && _word.hasMatch(text[match.start - 1]))
      return null;
    return MentionToken(match.start, caret, match.group(1)!.toLowerCase());
  }
}
