import 'dart:convert';

class ConfigNormalizationException implements Exception {
  final String message;
  const ConfigNormalizationException(this.message);
  @override
  String toString() => 'ConfigNormalizationException: $message';
}

class ConfigNormalizer {
  static const _defaultDns = {
    'servers': [
      {'address': '1.1.1.1', 'port': 53, 'skipFallback': false},
      {'address': '8.8.8.8', 'port': 53, 'skipFallback': false},
    ],
    'tag': 'vyre-dns',
  };

  String normalize(String rawConfig) {
    try {
      final decoded = jsonDecode(rawConfig);
      if (decoded is! Map<String, dynamic>) {
        throw const ConfigNormalizationException('Invalid config structure');
      }
      final config = decoded;
      _ensureDns(config);
      _ensureRoutingRules(config);
      _ensureDnsOutbound(config);
      _ensureBlockOutbound(config);
      return jsonEncode(config);
    } on FormatException {
      throw const ConfigNormalizationException('Invalid JSON');
    } on ConfigNormalizationException {
      rethrow;
    } on Exception {
      throw const ConfigNormalizationException('Normalization failed');
    }
  }

  void _ensureDns(Map<String, dynamic> config) {
    if (config.containsKey('dns')) return;
    config['dns'] = _defaultDns;
  }

  void _ensureRoutingRules(Map<String, dynamic> config) {
    final routing = config['routing'];
    if (routing is! Map<String, dynamic>) {
      if (config.containsKey('routing')) {
        throw const ConfigNormalizationException('Invalid routing structure');
      }
      return;
    }
    final rulesList = routing['rules'];
    final rules = (rulesList is List<dynamic>)
        ? rulesList.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    if (!rules.any((r) => r['port'] == '53' && r['outboundTag'] == 'vyre-dns-out')) {
      rules.insert(0, _dnsRule());
    }

    final hasIpv6Rule = rules.any((r) {
      final ip = r['ip'];
      return ip is List && ip.contains('::/0');
    });
    if (!hasIpv6Rule) {
      rules.add(_ipv6Rule());
    }

    if (!rules.any((r) {
      final proto = r['protocol'];
      return proto is List && proto.contains('bittorrent');
    })) {
      rules.add(_bittorrentRule());
    }

    if (!rules.any((r) => r['port'] == '3478')) {
      rules.add(_webrtcRule());
    }

    final newRouting = Map<String, dynamic>.from(routing);
    newRouting['rules'] = rules;
    config['routing'] = newRouting;
  }

  void _ensureDnsOutbound(Map<String, dynamic> config) {
    final outboundsList = config['outbounds'];
    if (outboundsList is! List<dynamic>) return;
    final outbounds = outboundsList.whereType<Map<String, dynamic>>().toList();
    final existingIndex = outbounds.indexWhere((o) => o['tag'] == 'vyre-dns-out');

    if (existingIndex >= 0) {
      if (outbounds[existingIndex]['protocol'] != 'dns') {
        throw ConfigNormalizationException('Existing vyre-dns-out outbound has wrong protocol: ${outbounds[existingIndex]['protocol']}');
      }
      return;
    }

    final newOutbounds = List<Map<String, dynamic>>.from(outbounds);
    newOutbounds.add({
      'protocol': 'dns',
      'tag': 'vyre-dns-out',
      'settings': {
        'network': 'udp',
        'address': '1.1.1.1',
        'port': 53,
      },
    });
    config['outbounds'] = newOutbounds;
  }

  void _ensureBlockOutbound(Map<String, dynamic> config) {
    final outboundsList = config['outbounds'];
    if (outboundsList is! List<dynamic>) return;
    final outbounds = outboundsList.whereType<Map<String, dynamic>>().toList();
    if (outbounds.any((o) => o['protocol'] == 'blackhole' && o['tag'] == 'block')) return;

    final newOutbounds = List<Map<String, dynamic>>.from(outbounds);
    newOutbounds.add({
      'protocol': 'blackhole',
      'tag': 'block',
    });

    config['outbounds'] = newOutbounds;
  }

  Map<String, dynamic> _ipv6Rule() => {
        'type': 'field',
        'ip': ['::/0'],
        'outboundTag': 'block',
      };

  Map<String, dynamic> _dnsRule() => {
        'type': 'field',
        'port': '53',
        'outboundTag': 'vyre-dns-out',
      };

  Map<String, dynamic> _bittorrentRule() => {
        'type': 'field',
        'protocol': ['bittorrent'],
        'outboundTag': 'block',
      };

  Map<String, dynamic> _webrtcRule() => {
        'type': 'field',
        'port': '3478',
        'network': 'udp',
        'outboundTag': 'block',
      };
}
