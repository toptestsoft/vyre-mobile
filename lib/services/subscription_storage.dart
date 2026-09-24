import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_cache.dart';

/// Тип результата чтения состояния хранилища подписки.
enum SubscriptionStorageStatus {
  /// Первое использование: флаг false, секрета нет.
  firstUse,

  /// Норма: флаг true, секрет читается.
  ok,

  /// Потеря данных: флаг true, секрета нет или чтение бросило исключение.
  storageLoss,

  /// Аномалия: флаг false, секрет есть. Трактуется как ok, но логируется warning.
  anomaly,
}

/// Результат классификации состояния хранилища подписки.
class SubscriptionStorageState {
  final SubscriptionStorageStatus status;
  final String? subscriptionUrl;
  final String? subscriptionName;
  final DateTime? importedAt;
  final int? serversCount;

  const SubscriptionStorageState({
    required this.status,
    this.subscriptionUrl,
    this.subscriptionName,
    this.importedAt,
    this.serversCount,
  });

  bool get isStorageLoss => status == SubscriptionStorageStatus.storageLoss;
}

/// Интерфейс хранилища подписки: секрет в защищённом слое,
/// метаданные — в обычном shared_preferences.
abstract class SubscriptionStorage {
  Future<void> writeSecret(String url);
  Future<String?> readSecret();
  Future<void> deleteSecret();

  Future<void> writeMetadata({
    required bool imported,
    String? name,
    DateTime? importedAt,
    int? serversCount,
  });
  Future<SubscriptionStorageState> readState();
  Future<void> clear();
}

/// Реализация: секрет — защищённое хранилище,
/// метаданные — SharedPreferences.
class DefaultSubscriptionStorage implements SubscriptionStorage {
  final SecureStorage _secure;
  final SharedPreferences _prefs;

  DefaultSubscriptionStorage({
    required SecureStorage secure,
    required SharedPreferences prefs,
  })  : _secure = secure,
        _prefs = prefs;

  static const _kSecretKey = 'vyre_active_subscription_url';
  static const _kImportedFlag = 'vyre_subscription_imported';
  static const _kName = 'vyre_subscription_name';
  static const _kImportedAt = 'vyre_subscription_imported_at';
  static const _kServersCount = 'vyre_subscription_servers_count';

  @override
  Future<void> writeSecret(String url) async {
    await _secure.write(key: _kSecretKey, value: url);
  }

  @override
  Future<String?> readSecret() async {
    return await _secure.read(key: _kSecretKey);
  }

  @override
  Future<void> deleteSecret() async {
    await _secure.delete(key: _kSecretKey);
  }

  @override
  Future<void> writeMetadata({
    required bool imported,
    String? name,
    DateTime? importedAt,
    int? serversCount,
  }) async {
    await _prefs.setBool(_kImportedFlag, imported);
    if (name != null) await _prefs.setString(_kName, name);
    if (importedAt != null) {
      await _prefs.setString(_kImportedAt, importedAt.toIso8601String());
    }
    if (serversCount != null) await _prefs.setInt(_kServersCount, serversCount);
  }

  @override
  Future<SubscriptionStorageState> readState() async {
    final imported = _prefs.getBool(_kImportedFlag) ?? false;
    String? secret;
    try {
      secret = await _secure.read(key: _kSecretKey);
    } catch (e) {
      // Чтение секрета бросило исключение — считаем, что секрета нет.
      secret = null;
    }

    if (!imported && secret == null) {
      return const SubscriptionStorageState(status: SubscriptionStorageStatus.firstUse);
    }

    if (imported && secret != null) {
      final name = _prefs.getString(_kName);
      final importedAtStr = _prefs.getString(_kImportedAt);
      final serversCount = _prefs.getInt(_kServersCount);
      return SubscriptionStorageState(
        status: SubscriptionStorageStatus.ok,
        subscriptionUrl: secret,
        subscriptionName: name,
        importedAt: importedAtStr != null ? DateTime.tryParse(importedAtStr) : null,
        serversCount: serversCount,
      );
    }

    if (imported && secret == null) {
      return const SubscriptionStorageState(status: SubscriptionStorageStatus.storageLoss);
    }

    // imported == false && secret != null — аномалия.
    return SubscriptionStorageState(
      status: SubscriptionStorageStatus.anomaly,
      subscriptionUrl: secret,
    );
  }

  @override
  Future<void> clear() async {
    await _secure.delete(key: _kSecretKey);
    await _prefs.remove(_kImportedFlag);
    await _prefs.remove(_kName);
    await _prefs.remove(_kImportedAt);
    await _prefs.remove(_kServersCount);
  }
}
