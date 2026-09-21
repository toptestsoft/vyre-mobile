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

    expect(rules.any((r) => (r as Map<String, dynamic>)['port'] == '53' && r['outboundTag'] == 'vyre-dns-out'), isTrue);
    expect(rules.first['port'], '53');
  });

  test('does not duplicate DNS routing rule', () {
    final config = {
      'routing': {
        'rules': [
          {'type': 'field', 'port': '53', 'outboundTag': 'vyre-dns-out'}
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

  test('throws ConfigNormalizationException on invalid JSON', () {
    final badJson = '{invalid json';
    expect(() => normalizer.normalize(badJson), throwsA(isA<ConfigNormalizationException>()));
  });

  test('throws ConfigNormalizationException on normalizer exception', () {
    final config = {'routing': 'bad'};
    expect(() => normalizer.normalize(jsonEncode(config)), throwsA(isA<ConfigNormalizationException>()));
  });

  test('DNS outbound automatically added', () {
    final config = {'outbounds': [{'protocol': 'vless', 'tag': 'proxy'}]};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final outbounds = parsed['outbounds'] as List<dynamic>;

    expect(outbounds.any((o) => (o as Map<String, dynamic>)['protocol'] == 'dns' && o['tag'] == 'vyre-dns-out'), isTrue);
  });

  test('does not duplicate vyre-dns-out outbound', () {
    final config = {
      'outbounds': [
        {'protocol': 'dns', 'tag': 'vyre-dns-out'},
        {'protocol': 'vless', 'tag': 'proxy'}
      ]
    };
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final outbounds = parsed['outbounds'] as List<dynamic>;

    expect(outbounds.where((o) => (o as Map<String, dynamic>)['tag'] == 'vyre-dns-out').length, 1);
  });

  test('preserves existing vyre-dns-out with protocol dns', () {
    final config = {
      'outbounds': [
        {'protocol': 'dns', 'tag': 'vyre-dns-out'},
        {'protocol': 'vless', 'tag': 'proxy'}
      ]
    };
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final outbounds = parsed['outbounds'] as List<dynamic>;

    final dnsOutbound = outbounds.firstWhere((o) => (o as Map<String, dynamic>)['tag'] == 'vyre-dns-out');
    expect(dnsOutbound['protocol'], 'dns');
  });

  test('throws ConfigNormalizationException when vyre-dns-out has wrong protocol', () {
    final config = {
      'outbounds': [
        {'protocol': 'vless', 'tag': 'vyre-dns-out'},
        {'protocol': 'vless', 'tag': 'proxy'}
      ]
    };
    expect(() => normalizer.normalize(jsonEncode(config)), throwsA(isA<ConfigNormalizationException>()));
  });

  test('routing rule outboundTag vyre-dns-out continues to exist', () {
    final config = {'routing': {'rules': []}, 'outbounds': []};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final rules = (parsed['routing'] as Map<String, dynamic>)['rules'] as List<dynamic>;

    expect(rules.any((r) => (r as Map<String, dynamic>)['outboundTag'] == 'vyre-dns-out'), isTrue);
  });

  test('DNS outbound has settings with network address port', () {
    final config = {'outbounds': [{'protocol': 'vless', 'tag': 'proxy'}]};
    final result = normalizer.normalize(jsonEncode(config));
    final parsed = jsonDecode(result) as Map<String, dynamic>;
    final outbounds = parsed['outbounds'] as List<dynamic>;

    final dnsOutbound = outbounds.firstWhere((o) => (o as Map<String, dynamic>)['tag'] == 'vyre-dns-out');
    expect(dnsOutbound['protocol'], 'dns');
    expect(dnsOutbound['settings'], isNotNull);
    expect((dnsOutbound['settings'] as Map<String, dynamic>)['network'], 'udp');
    expect((dnsOutbound['settings'] as Map<String, dynamic>)['address'], '1.1.1.1');
    expect((dnsOutbound['settings'] as Map<String, dynamic>)['port'], 53);
  });
}
