import 'dart:convert';

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
      final config = jsonDecode(rawConfig) as Map<String, dynamic>;
      _ensureDns(config);
      _ensureRoutingRules(config);
      _ensureBlockOutbound(config);
      return jsonEncode(config);
    } on FormatException {
      return rawConfig;
    } on Exception {
      return rawConfig;
    }
  }

  void _ensureDns(Map<String, dynamic> config) {
    if (config.containsKey('dns')) return;
    config['dns'] = _defaultDns;
  }

  void _ensureRoutingRules(Map<String, dynamic> config) {
    final routing = config['routing'] as Map<String, dynamic>? ?? {};
    final rules = (routing['rules'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];

    if (!rules.any((r) => r['port'] == '53' && r['outboundTag'] == 'vyre-dns')) {
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

  Map<String, dynamic> _ipv6Rule() => {
        'type': 'field',
        'ip': ['::/0'],
        'outboundTag': 'block',
      };

  Map<String, dynamic> _dnsRule() => {
        'type': 'field',
        'port': '53',
        'outboundTag': 'vyre-dns',
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

  void _ensureBlockOutbound(Map<String, dynamic> config) {
    final outbounds = (config['outbounds'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    if (outbounds.any((o) => o['protocol'] == 'blackhole' && o['tag'] == 'block')) return;

    final newOutbounds = List<Map<String, dynamic>>.from(outbounds);
    newOutbounds.add({
      'protocol': 'blackhole',
      'tag': 'block',
    });

    config['outbounds'] = newOutbounds;
  }
}
