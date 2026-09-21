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

  Future<void> _cleanupOldChunks(String key) async {
    await _secure.delete(key: '${key}_count');
    for (var i = 0; i < 100; i++) {
      await _secure.delete(key: '${key}_part_$i');
    }
    await _secure.delete(key: key);
  }

  Future<void> write(String subUrl, String body) async {
    try {
      final key = await _keyFor(subUrl);
      final bodyBytes = utf8.encode(body);

      if (bodyBytes.length <= _chunkSize) {
        await _cleanupOldChunks(key);
        await _secure.write(key: key, value: base64.encode(bodyBytes));
      } else {
        await _cleanupOldChunks(key);

        final chunks = <List<int>>[];
        for (var i = 0; i < bodyBytes.length; i += _chunkSize) {
          final end = i + _chunkSize > bodyBytes.length ? bodyBytes.length : i + _chunkSize;
          chunks.add(bodyBytes.sublist(i, end));
        }

        for (var i = 0; i < chunks.length; i++) {
          await _secure.write(key: '${key}_part_$i', value: base64.encode(chunks[i]));
        }

        await _secure.write(key: '${key}_count', value: chunks.length.toString());
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

        final allBytes = <int>[];
        for (var i = 0; i < count; i++) {
          final chunkB64 = await _secure.read(key: '${key}_part_$i');
          if (chunkB64 == null) return null;
          allBytes.addAll(base64.decode(chunkB64));
        }

        final body = utf8.decode(allBytes);
        return body.isEmpty ? null : body;
      }

      final raw = await _secure.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      try {
        final bytes = base64.decode(raw);
        return utf8.decode(bytes);
      } on FormatException {
        return raw;
      }
    } catch (_) {
      return null;
    }
  }
}
