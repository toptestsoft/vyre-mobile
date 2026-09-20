import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/services/subscription_service.dart';
import 'package:vyre/services/subscription_cache.dart';
import 'package:vyre/services/config_validator.dart';
import 'package:vyre/services/config_normalizer.dart';
import 'package:vyre/services/server_selector.dart';
import 'package:vyre/models/subscription.dart';

void main() {
  test('full flow: parse -> validate -> normalize -> sort -> selectBest', () async {
    final cache = SubscriptionCache();
    final service = SubscriptionService(cache);
    final validator = ConfigValidator();
    final normalizer = ConfigNormalizer();
    final selector = ServerSelector();

    final body = 'vless://uuid@example.com:443?encryption=none&security=tls&type=tcp#Server1\n'
                 'vless://uuid@192.168.1.1:443?encryption=none&security=tls&type=tcp#BadPrivate\n'
                 'vless://uuid@malicious.example.com:443?encryption=none&protocol=malicious#BadProtocol';

    final parsed = service.parseToV2RayUrls(body, isSingleLink: false);
    expect(parsed.length, 3);

    final validParsed = <dynamic>[];
    final configs = <Map<String, dynamic>>[];

    for (final p in parsed) {
      try {
        final rawCfg = p.getFullConfiguration();
        final cfg = jsonDecode(rawCfg);
        validator.validate(cfg);
        final normalized = normalizer.normalize(rawCfg);
        validParsed.add(p);
        configs.add(jsonDecode(normalized));
      } on Exception {
        // skip invalid
      }
    }

    expect(validParsed.length, 2);

    final rows = configs.map((cfg) {
      return ServerRow(
        remark: 'Server',
        config: jsonEncode(cfg),
        delayMs: cfg == configs.first ? 50 : 120,
      );
    }).toList();

    final sorted = selector.sort(rows);
    final best = selector.selectBest(sorted);

    expect(best, isNotNull);
    expect(best!.delayMs, 50);

    final normalizedConfig = jsonDecode(best.config);
    expect(normalizedConfig['dns'], isNotNull);
    expect(normalizedConfig['routing']['rules'], isNotNull);
    expect(normalizedConfig['outbounds'], isNotNull);
  });
}
