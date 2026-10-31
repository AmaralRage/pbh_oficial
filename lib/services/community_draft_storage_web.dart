import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<web.IDBDatabase> _open() {
  final complete = Completer<web.IDBDatabase>();
  final factory = web.window.indexedDB;
  final request = factory.open('pbh-community-drafts', 1);
  request.onupgradeneeded = ((web.Event _) {
    (request.result as web.IDBDatabase).createObjectStore('drafts');
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final db=request.result as web.IDBDatabase;
    if (!complete.isCompleted) { complete.complete(db); } else { db.close(); }
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!complete.isCompleted)
      complete.completeError(
        StateError('Não foi possível abrir os rascunhos.'),
      );
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!complete.isCompleted)
      complete.completeError(
        StateError('Feche outras abas do app e tente novamente.'),
      );
  }).toJS;
  return complete.future;
}

Future<String?> _transaction(
  String key, {
  String? value,
  bool remove = false,
}) async {
  final db = await _open(), result = Completer<String?>();
  final tx = db.transaction(
    'drafts'.toJS,
    value != null || remove ? 'readwrite' : 'readonly',
  );
  final store = tx.objectStore('drafts');
  String? loaded;
  final request = remove
      ? store.delete(key.toJS)
      : value != null
      ? store.put(value.toJS, key.toJS)
      : store.get(key.toJS);
  request.onsuccess = ((web.Event _) {
    if (value == null && !remove) loaded = request.result?.dartify() as String?;
  }).toJS;
  tx.oncomplete = ((web.Event _) {
    db.close();
    if (!result.isCompleted) result.complete(loaded);
  }).toJS;
  void fail(web.Event _) {
    db.close();
    if (!result.isCompleted)
      result.completeError(
        StateError(
          'Não foi possível salvar o rascunho. Confira o espaço disponível.',
        ),
      );
  }

  tx.onerror = fail.toJS;
  tx.onabort = fail.toJS;
  return result.future;
}

Future<String?> readDraft(String key) => _transaction(key);
Future<void> writeDraft(String key, String value) async {
  await _transaction(key, value: value);
}

Future<void> removeDraft(String key) async {
  await _transaction(key, remove: true);
}
