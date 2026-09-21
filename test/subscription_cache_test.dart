import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/services/subscription_cache.dart';

class FakeSecureStorage implements SecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return _data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  Map<String, String> get snapshot => Map.unmodifiable(_data);
}

void main() {
  group('SubscriptionCache', () {
    test('large then small: old chunks are removed', () async {
      final storage = FakeSecureStorage();
      final cache = SubscriptionCache(secureStorage: storage);

      final largeBody = 'x' * 25000;
      await cache.write('https://example.com/sub', largeBody);
      expect(await cache.read('https://example.com/sub'), largeBody);

      final smallBody = 'small';
      await cache.write('https://example.com/sub', smallBody);
      expect(await cache.read('https://example.com/sub'), smallBody);

      final keys = storage.snapshot.keys.toList();
      expect(keys.where((k) => k.contains('_part_')), isEmpty);
      expect(keys.where((k) => k.endsWith('_count')), isEmpty);
    });

    test('small then large: single key is removed and chunks are used', () async {
      final storage = FakeSecureStorage();
      final cache = SubscriptionCache(secureStorage: storage);

      final smallBody = 'small';
      await cache.write('https://example.com/sub', smallBody);
      expect(await cache.read('https://example.com/sub'), smallBody);

      final largeBody = 'y' * 25000;
      await cache.write('https://example.com/sub', largeBody);
      expect(await cache.read('https://example.com/sub'), largeBody);

      final keys = storage.snapshot.keys.toList();
      expect(keys.where((k) => k.endsWith('_count')), isNotEmpty);
      expect(keys.where((k) => k.contains('_part_')), isNotEmpty);
    });

    test('rewrite same size: data is overwritten correctly', () async {
      final storage = FakeSecureStorage();
      final cache = SubscriptionCache(secureStorage: storage);

      final body1 = 'a' * 25000;
      await cache.write('https://example.com/sub', body1);
      expect(await cache.read('https://example.com/sub'), body1);

      final body2 = 'b' * 25000;
      await cache.write('https://example.com/sub', body2);
      expect(await cache.read('https://example.com/sub'), body2);
      expect(await cache.read('https://example.com/sub'), isNot(body1));
    });
  });
}
