import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Кэш последней УСПЕШНОЙ подписки в защищенном хранилище.
/// Позволяет подключаться без сети (offline-first).
class SubscriptionCache {
  static final _secure = FlutterSecureStorage();
  static const _chunkSize = 12000;

  Future<String> _keyFor(String subUrl) async {
    final bytes = utf8.encode(subUrl);
    final digest = sha256.convert(bytes);
    return 'vyre_sub_${digest.toString()}';
  }

  Future<void> write(String subUrl, String body) async {
    try {
      final key = await _keyFor(subUrl);
      if (body.length <= _chunkSize) {
        await _secure.write(key: key, value: body);
        await _secure.delete(key: '${key}_count');
      } else {
        final chunks = <String>[];
        for (var i = 0; i < body.length; i += _chunkSize) {
          final end = i + _chunkSize > body.length ? body.length : i + _chunkSize;
          chunks.add(body.substring(i, end));
        }
        await _secure.write(key: '${key}_count', value: chunks.length.toString());
        for (var i = 0; i < chunks.length; i++) {
          await _secure.write(key: '${key}_part_$i', value: chunks[i]);
        }
        await _secure.delete(key: key);
      }
    } catch (_) {
      // кэш не критичен
    }
  }

  Future<String?> read(String subUrl) async {
    try {
      final key = await _keyFor(subUrl);

      final countStr = await _secure.read(key: '${key}_count');
      if (countStr != null) {
        final count = int.tryParse(countStr);
        if (count == null || count <= 0) return null;
        final buffer = StringBuffer();
        for (var i = 0; i < count; i++) {
          final chunk = await _secure.read(key: '${key}_part_$i');
          if (chunk == null) return null;
          buffer.write(chunk);
        }
        final body = buffer.toString();
        return body.isEmpty ? null : body;
      }

      final raw = await _secure.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      return raw;
    } catch (_) {
      return null;
    }
  }
}
