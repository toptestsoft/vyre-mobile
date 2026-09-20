import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/services/config_normalizer.dart';

void main() {
  final normalizer = ConfigNormalizer();

  test('adds DNS section if missing', () {
    final config = {'outbounds': []};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;

    expect(parsed.containsKey('dns'), isTrue);
    expect((parsed['dns'] as Map<String, dynamic>)['tag'], 'vyre-dns');
  });

  test('preserves existing DNS section', () {
    final config = {'dns': {'servers': [{'address': 'custom.dns', 'port': 53}]}};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;

    expect((parsed['dns'] as Map<String, dynamic>)['servers'].length, 1);
  });

  test('adds DNS routing rule if missing', () {
    final config = {'routing': {'rules': []}, 'outbounds': []};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final rules = (parsed['routing'] as Map<String, dynamic>)['rules'] as List<dynamic>;

    expect(rules.any((r) => (r as Map<String, dynamic>)['port'] == '53' && r['outboundTag'] == 'vyre-dns'), isTrue);
    expect(rules.first['port'], '53');
  });

  test('does not duplicate DNS routing rule', () {
    final config = {
      'routing': {
        'rules': [
          {'type': 'field', 'port': '53', 'outboundTag': 'vyre-dns'}
        ]
      },
      'outbounds': []
    };
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final rules = (parsed['routing'] as Map<String, dynamic>)['rules'] as List<dynamic>;

    expect(rules.where((r) => (r as Map<String, dynamic>)['port'] == '53').length, 1);
  });

  test('adds IPv6 blocking rule', () {
    final config = {'routing': {'rules': []}, 'outbounds': []};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final rules = (parsed['routing'] as Map<String, dynamic>)['rules'] as List<dynamic>;

    expect(rules.any((r) => (r as Map<String, dynamic>)['ip'] is List && (r['ip'] as List).contains('::/0')), isTrue);
  });

  test('adds WebRTC blocking rules', () {
    final config = {'routing': {'rules': []}, 'outbounds': []};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final rules = (parsed['routing'] as Map<String, dynamic>)['rules'] as List<dynamic>;

    expect(rules.any((r) => (r as Map<String, dynamic>)['protocol'] is List && (r['protocol'] as List).contains('bittorrent')), isTrue);
    expect(rules.any((r) => (r as Map<String, dynamic>)['port'] == '3478'), isTrue);
  });

  test('adds block outbound if missing', () {
    final config = {'outbounds': [{'protocol': 'vless', 'tag': 'proxy'}]};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final outbounds = parsed['outbounds'] as List<dynamic>;

    expect(outbounds.any((o) => (o as Map<String, dynamic>)['protocol'] == 'blackhole'), isTrue);
  });

  test('returns original config on invalid JSON', () {
    final badJson = '{invalid json';
    final result = normalizer.normalize(badJson);
    expect(result, badJson);
  });
}
