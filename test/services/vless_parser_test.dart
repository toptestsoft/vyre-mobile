import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/services/vless_parser.dart';

void main() {
  group('VLESS Link Parser', () {
    test('Valid VLESS link parses correctly', () {
      const link = 'vless://uuid@domain.com:443?type=tcp&security=reality&pbk=test&sid=12345678#VlessNode';
      final result = VlessParser.parse(link);
      
      expect(result.uuid, equals('uuid'));
      expect(result.server, equals('domain.com'));
      expect(result.port, equals(443));
      expect(result.security, equals('reality'));
      expect(result.pbk, equals('test'));
      expect(result.sid, equals('12345678'));
      expect(result.remark, equals('VlessNode'));
    });

    test('Invalid link throws FormatException', () {
      expect(() => VlessParser.parse('vless://invalid'), throwsA(isA<FormatException>()));
    });

    test('Missing port defaults to 443', () {
      const link = 'vless://uuid@domain.com?type=tcp&security=reality&pbk=test&sid=12345678';
      final result = VlessParser.parse(link);
      expect(result.port, equals(443));
    });

    test('VLESS over WebSocket parses correctly', () {
      const link = 'vless://uuid@domain.com:443?type=ws&host=example.com&path=%2F&security=reality&pbk=test&sid=abcd1234';
      final result = VlessParser.parse(link);
      expect(result.type, equals('ws'));
      expect(result.host, equals('example.com'));
      expect(result.path, equals('/'));
    });
  });
}
