class ConfigValidationException implements Exception {
  final String message;
  ConfigValidationException(this.message);
  @override
  String toString() => 'ConfigValidationException: $message';
}

class ConfigValidator {
  static const allowedProtocols = <String>{
    'vless',
    'trojan',
    'shadowsocks',
    'vmess',
    'wireguard',
    'freedom',
    'blackhole',
  };

  bool _isPrivateOrLocal(String address) {
    // IPv4 checks
    if (address == '127.0.0.1') return true;
    if (address.startsWith('10.')) return true;
    if (address.startsWith('192.168.')) return true;

    // 172.16.0.0 - 172.31.255.255
    if (address.startsWith('172.')) {
      final parts = address.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]);
        if (second != null && second >= 16 && second <= 31) {
          return true;
        }
      }
    }

    if (address.startsWith('169.254.')) return true; // Link-local

    // IPv6 checks
    final lower = address.toLowerCase();
    if (lower == '::1' || lower == 'localhost') return true;
    if (lower.startsWith('fc') || lower.startsWith('fd')) return true; // fc00::/7
    if (lower.startsWith('fe80')) return true; // fe80::/10 link-local

    // IPv4-mapped IPv6: ::ffff:192.168.1.1
    if (lower.startsWith('::ffff:')) {
      final ipv4Part = address.substring(7); // Убираем '::ffff:'
      return _isPrivateOrLocal(ipv4Part);
    }

    return false;
  }

  void validate(Map<String, dynamic> config) {
    final outbounds = config['outbounds'] as List? ?? [];

    for (final out in outbounds) {
      final protocol = out['protocol'] as String?;
      if (protocol == null || !allowedProtocols.contains(protocol.toLowerCase())) {
        throw ConfigValidationException('Unsupported protocol: $protocol');
      }

      final server = out['settings']?['vnext']?.first?['address'] as String?
              ?? out['settings']?['servers']?.first?['address'] as String?;
      if (server != null && _isPrivateOrLocal(server)) {
        throw ConfigValidationException('Connection to private address is forbidden');
      }
    }
  }
}
