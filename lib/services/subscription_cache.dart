import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Кэш последней УСПЕШНОЙ подписки на диске.
/// Позволяет подключаться без сети (offline-first).
class SubscriptionCache {
  Future<File> _fileFor(String subUrl) async {
    final dir = await getApplicationCacheDirectory();
    final key = base64Url.encode(utf8.encode(subUrl)).replaceAll('=', '');
    return File('${dir.path}/sub_$key.txt');
  }

  Future<void> write(String subUrl, String body) async {
    try {
      final f = await _fileFor(subUrl);
      await f.writeAsString(body, flush: true);
    } catch (_) {} // кэш не критичен
  }

  Future<String?> read(String subUrl) async {
    try {
      final f = await _fileFor(subUrl);
      if (!await f.exists()) return null;
      final body = await f.readAsString();
      return body.isEmpty ? null : body;
    } catch (_) {
      return null;
    }
  }
}
