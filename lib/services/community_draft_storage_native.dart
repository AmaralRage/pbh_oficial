import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File> _file(String key) async {
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/community-drafts');
  await directory.create(recursive: true);
  return File('${directory.path}/$key.json');
}

Future<String?> readDraft(String key) async {
  final file = await _file(key);
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeDraft(String key, String value) async {
  final file = await _file(key),
      pending = File('${(await _file(key)).path}.pending');
  await pending.writeAsString(value, flush: true);
  await pending.rename(file.path);
}

Future<void> removeDraft(String key) async {
  final file = await _file(key);
  if (await file.exists()) await file.delete();
}
