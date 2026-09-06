import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/models/subscription.dart';

void main() {
  group('Subscription Model', () {
    test('From JSON creates valid object', () {
      final json = {
        'id': 'sub-1',
        'name': 'Main',
        'url': 'https://example.com/sub',
        'isActive': true,
        'createdAt': '2024-01-01T00:00:00Z',
      };
      
      final sub = Subscription.fromJson(json);
      expect(sub.id, equals('sub-1'));
      expect(sub.name, equals('Main'));
      expect(sub.url, equals('https://example.com/sub'));
      expect(sub.isActive, isTrue);
    });

    test('To JSON round-trips correctly', () {
      final sub = Subscription(
        id: 'sub-2',
        name: 'Backup',
        url: 'https://backup.com/sub',
        isActive: false,
        createdAt: DateTime(2024, 6, 15),
      );

      final json = sub.toJson();
      final restored = Subscription.fromJson(json);
      
      expect(restored.id, equals(sub.id));
      expect(restored.name, equals(sub.name));
      expect(restored.url, equals(sub.url));
      expect(restored.isActive, equals(sub.isActive));
    });
  });
}
