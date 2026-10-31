import 'dart:convert';
import '../models/community_photo.dart';
import 'community_draft_storage.dart' as storage;

class CommunityDraft {
  const CommunityDraft({
    required this.id,
    required this.text,
    required this.tag,
    required this.topic,
    required this.photos,
  });
  final String id, text, tag, topic;
  final List<CommunityPhoto> photos;
  Map<String, dynamic> toMap() => {
    'schema': 1,
    'id': id,
    'text': text,
    'tag': tag,
    'topic': topic,
    'photos': [for (final p in photos) base64Encode(p.bytes)],
  };
  factory CommunityDraft.fromMap(Map<String, dynamic> value) {
    final raw = value['photos'] as List;
    if (value['schema'] != 1 ||
        raw.length > CommunityPhoto.maxCount ||
        (value['text'] as String).length > 20000 ||
        (value['tag'] as String).length > 800 ||
        !RegExp(r'^[0-9a-f-]{36}$').hasMatch(value['id'] as String))
      throw const FormatException('Rascunho inválido.');
    return CommunityDraft(
      id: value['id'] as String,
      text: value['text'] as String,
      tag: value['tag'] as String,
      topic: value['topic'] as String,
      photos: [
        for (final bytes in raw) CommunityPhoto(base64Decode(bytes as String)),
      ],
    );
  }
}

class CommunityDraftStore {
  CommunityDraftStore({
    this.read = storage.readDraft,
    this.write = storage.writeDraft,
    this.remove = storage.removeDraft,
  });
  final Future<String?> Function(String) read;
  final Future<void> Function(String, String) write;
  final Future<void> Function(String) remove;
  String _key(String user) =>
      base64UrlEncode(utf8.encode(user)).replaceAll('=', '');
  Future<CommunityDraft?> load(String user) async {
    final text = await read(_key(user));
    if (text == null) return null;
    if (text.length > 150 * 1024 * 1024)
      throw const FormatException('Rascunho muito grande.');
    return CommunityDraft.fromMap(jsonDecode(text) as Map<String, dynamic>);
  }

  Future<void> save(String user, CommunityDraft draft) =>
      write(_key(user), jsonEncode(draft.toMap()));
  Future<void> clear(String user) => remove(_key(user));
}
