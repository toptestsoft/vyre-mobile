import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription.dart';

/// Хранилище подписок. UI не знает, где лежат данные.
class SubscriptionRepository {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kSubs = 'subscriptions_secure';
  static const _kActive = 'active_subscription_id_secure';

  Future<List<SubscriptionItem>> loadAll() async {
    final migrated = await _migrateIfNeeded();
    if (migrated != null) return migrated;
    try {
      final raw = await _secure.read(key: _kSubs);
      if (raw == null || raw.isEmpty) return [];
      return (json.decode(raw) as List)
          .map((j) => SubscriptionItem.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('VYRE repo: ошибка чтения: $e');
      return [];
    }
  }

  Future<String?> loadActiveId(List<SubscriptionItem> subs) async {
    final id = await _secure.read(key: _kActive);
    return (id != null && subs.any((s) => s.id == id)) ? id : null;
  }

  Future<void> saveAll(List<SubscriptionItem> subs, String? activeId) async {
    try {
      await _secure.write(key: _kSubs, value: json.encode(subs.map((s) => s.toJson()).toList()));
      await _secure.write(key: _kActive, value: activeId ?? '');
    } catch (e) {
      debugPrint('VYRE repo: ошибка записи: $e');
    }
  }

  /// Одноразовая миграция из открытого SharedPreferences.
  Future<List<SubscriptionItem>?> _migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getStringList('subscriptions');
    if (old == null || old.isEmpty) return null;
    final subs = old
        .map((j) => SubscriptionItem.fromJson(json.decode(j) as Map<String, dynamic>))
        .toList();
    await saveAll(subs, prefs.getString('active_subscription_id'));
    await prefs.remove('subscriptions');
    await prefs.remove('active_subscription_id');
    debugPrint('VYRE repo: мигрировано ${subs.length} подписок');
    return subs;
  }
}
