import 'dart:io';

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
  };

  bool _isPrivateOrLocal(String address) {
    final lower = address.toLowerCase();
    if (lower == 'localhost') return true;

    final addr = InternetAddress.tryParse(address);
    if (addr == null) return false;

    if (addr.isLoopback || addr.isMulticast || addr.isLinkLocal) return true;
    if (address == '0.0.0.0' || address == '::' || address == '255.255.255.255') return true;

    // 127.0.0.0/8
    if (addr.type == InternetAddressType.IPv4 && address.startsWith('127.')) return true;

    if (addr.type == InternetAddressType.IPv4) {
      final parts = address.split('.');
      if (parts.length == 4) {
        final octets = parts.map(int.tryParse).whereType<int>().toList();
        if (octets.length == 4) {
          if (octets[0] == 10) return true;
          if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) return true;
          if (octets[0] == 192 && octets[1] == 168) return true;
        }
      }
    }

    if (addr.type == InternetAddressType.IPv6) {
      final lower = address.toLowerCase();
      if (lower.startsWith('fc') || lower.startsWith('fd')) return true; // fc00::/7

      if (lower.startsWith('::ffff:')) {
        final ipv4Part = address.substring(7);
        return _isPrivateOrLocal(ipv4Part);
      }
    }

    return false;
  }

  void validate(Map<String, dynamic> config) {
    final outbounds = (config['outbounds'] as List? ?? [])
        .where((out) => out['settings']?['vnext'] != null || out['settings']?['servers'] != null)
        .toList();

    for (final out in outbounds) {
      final protocol = out['protocol'] as String?;
      if (protocol == null || !allowedProtocols.contains(protocol.toLowerCase())) {
        throw ConfigValidationException('Unsupported protocol: $protocol');
      }

      final vnext = out['settings']?['vnext'] as List?;
      final servers = out['settings']?['servers'] as List?;
      final addresses = <String>[];

      if (vnext != null) {
        for (final item in vnext) {
          final addr = item?['address'] as String?;
          if (addr != null) addresses.add(addr);
        }
      }

      if (servers != null) {
        for (final item in servers) {
          final addr = item?['address'] as String?;
          if (addr != null) addresses.add(addr);
        }
      }

      for (final address in addresses) {
        if (_isPrivateOrLocal(address)) {
          throw ConfigValidationException('Connection to private address is forbidden: $address');
        }
      }
    }
  }
}
