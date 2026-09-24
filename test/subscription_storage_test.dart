import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyre/services/subscription_cache.dart';
import 'package:vyre/services/subscription_storage.dart';

class FakeSecureStorage implements SecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _data[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }

  Map<String, String> get snapshot => Map.unmodifiable(_data);
}

class FakeSharedPreferences implements SharedPreferences {
  final Map<String, Object> _data = {};

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) => _data[key] as List<String>?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  double? getDouble(String key) => _data[key] as double?;

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {}

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Object? get(String key) => _data[key];

  bool get onValueChanged => false;

  @override
  Set<String> getKeys() => _data.keys.toSet();

  @override
  bool containsKey(String key) => _data.containsKey(key);
}

void main() {
  group('DefaultSubscriptionStorage', () {
    late FakeSecureStorage secure;
    late FakeSharedPreferences prefs;
    late DefaultSubscriptionStorage storage;

    setUp(() {
      secure = FakeSecureStorage();
      prefs = FakeSharedPreferences();
      storage = DefaultSubscriptionStorage(secure: secure, prefs: prefs);
    });

    test('firstUse: flag false, no secret', () async {
      await storage.writeMetadata(imported: false);
      final state = await storage.readState();
      expect(state.status, SubscriptionStorageStatus.firstUse);
      expect(state.subscriptionUrl, isNull);
    });

    test('ok: flag true, secret readable', () async {
      await storage.writeSecret('https://example.com/sub');
      await storage.writeMetadata(
        imported: true,
        name: 'Test Sub',
        importedAt: DateTime(2026, 1, 1),
        serversCount: 3,
      );
      final state = await storage.readState();
      expect(state.status, SubscriptionStorageStatus.ok);
      expect(state.subscriptionUrl, 'https://example.com/sub');
      expect(state.subscriptionName, 'Test Sub');
      expect(state.serversCount, 3);
    });

    test('storageLoss: flag true, secret missing', () async {
      await storage.writeMetadata(imported: true);
      final state = await storage.readState();
      expect(state.status, SubscriptionStorageStatus.storageLoss);
      expect(state.subscriptionUrl, isNull);
    });

    test('storageLoss: flag true, secret read throws', () async {
      await storage.writeSecret('https://example.com/sub');
      await storage.writeMetadata(imported: true);
      // Simulate secure storage failure by clearing it after metadata write.
      secure._data.clear();
      final state = await storage.readState();
      expect(state.status, SubscriptionStorageStatus.storageLoss);
    });

    test('anomaly: flag false, secret exists -> treated as anomaly', () async {
      await storage.writeSecret('https://example.com/sub');
      await storage.writeMetadata(imported: false);
      final state = await storage.readState();
      expect(state.status, SubscriptionStorageStatus.anomaly);
      expect(state.subscriptionUrl, 'https://example.com/sub');
    });

    test('dismiss banner resets imported flag', () async {
      await storage.writeMetadata(imported: true);
      var state = await storage.readState();
      expect(state.status, SubscriptionStorageStatus.storageLoss);

      await storage.writeMetadata(imported: false);
      state = await storage.readState();
      expect(state.status, SubscriptionStorageStatus.firstUse);
    });
  });
}
