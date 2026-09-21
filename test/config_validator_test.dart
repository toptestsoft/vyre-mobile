import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/services/config_validator.dart';

void main() {
  final validator = ConfigValidator();

  test('accepts valid VLESS config', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': 'example.com', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), returnsNormally);
  });

  test('rejects localhost', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': 'localhost', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects LOCALHOST uppercase', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': 'LOCALHOST', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects private IP', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '192.168.1.1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects unsupported protocol', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'malicious',
          'settings': {
            'vnext': [
              {'address': 'example.com', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('allows public 172.x.x.x outside private range', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '172.32.0.1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), returnsNormally);
  });

  test('rejects 172.16.0.1 (private range)', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '172.16.0.1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects IPv6 link-local', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': 'fe80::1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects IPv4-mapped IPv6 private address', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '::ffff:192.168.1.1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('accepts uppercase protocol', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'VLESS',
          'settings': {
            'vnext': [
              {'address': 'example.com', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), returnsNormally);
  });

  test('rejects freedom protocol', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'freedom',
          'settings': {
            'vnext': [
              {'address': 'example.com', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects blackhole protocol', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'blackhole',
          'settings': {
            'servers': [
              {'address': 'example.com', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('skips internal outbound without vnext/servers', () {
    final config = {
      'outbounds': [
        {'protocol': 'freedom', 'settings': {}},
        {'protocol': 'blackhole', 'settings': {}},
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': 'example.com', 'port': 443}
            ]
          }
        },
      ]
    };
    expect(() => validator.validate(config), returnsNormally);
  });

  test('rejects second server in list', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': 'example.com', 'port': 443},
              {'address': '192.168.1.1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects 0.0.0.0', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '0.0.0.0', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects multicast address', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '224.0.0.1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects alternative loopback 127.0.0.2', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '127.0.0.2', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects broadcast address', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '255.255.255.255', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('allows domain names', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': 'example.com', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), returnsNormally);
  });

  test('allows invalid IP strings', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': 'not.an.ip', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), returnsNormally);
  });

  test('allows 172.15.255.255 (public)', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '172.15.255.255', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), returnsNormally);
  });

  test('rejects 172.16.0.1 (private)', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '172.16.0.1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('rejects 172.31.255.255 (private)', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '172.31.255.255', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), throwsA(isA<ConfigValidationException>()));
  });

  test('allows 172.32.0.1 (public)', () {
    final config = {
      'outbounds': [
        {
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {'address': '172.32.0.1', 'port': 443}
            ]
          }
        }
      ]
    };
    expect(() => validator.validate(config), returnsNormally);
  });
}
