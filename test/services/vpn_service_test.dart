import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/services/vpn_service.dart';

class FakeV2rayEngine implements V2rayEngine {
  FakeV2rayEngine({
    this.delayMs = 0,
    this.failInitialize = false,
    this.failGetServerDelay = false,
    this.failStartV2Ray = false,
    this.failStopV2Ray = false,
    this.failRequestPermission = false,
  });

  final int delayMs;
  final bool failInitialize;
  final bool failGetServerDelay;
  final bool failStartV2Ray;
  final bool failStopV2Ray;
  final bool failRequestPermission;

  int getServerDelayCalls = 0;
  int startV2RayCalls = 0;
  int stopV2RayCalls = 0;

  @override
  Future<void> initializeV2Ray() async {
    if (failInitialize) throw Exception('initialize failed');
  }

  @override
  Future<void> startV2Ray({required String remark, required String config, List<String>? blockedApps}) async {
    startV2RayCalls++;
    if (failStartV2Ray) throw Exception('start failed');
    if (delayMs > 0) await Future.delayed(Duration(milliseconds: delayMs));
  }

  @override
  Future<void> stopV2Ray() async {
    stopV2RayCalls++;
    if (failStopV2Ray) throw Exception('stop failed');
    if (delayMs > 0) await Future.delayed(Duration(milliseconds: delayMs));
  }

  @override
  Future<int> getServerDelay({required String config}) async {
    getServerDelayCalls++;
    if (failGetServerDelay) throw Exception('ping failed');
    if (delayMs > 0) await Future.delayed(Duration(milliseconds: delayMs));
    return 50;
  }

  @override
  Future<bool> requestPermission() async {
    if (failRequestPermission) return false;
    return true;
  }
}

void main() {
  group('VpnService', () {
    test('pingServer returns -1 when engine throws', () async {
      final engine = FakeV2rayEngine(failGetServerDelay: true);
      final service = VpnService(onStateChanged: (_, __) {}, engine: engine);
      service.setInitializedForTests(true);

      final result = await service.pingServer('config');
      expect(result, -1);
    });

    test('connect throws when engine throws', () async {
      final engine = FakeV2rayEngine(failStartV2Ray: true);
      final service = VpnService(onStateChanged: (_, __) {}, engine: engine);
      service.setInitializedForTests(true);

      expect(() => service.connect(remark: 'r', config: 'c'), throwsA(isA<Exception>()));
    });

    test('disconnect does not throw when engine succeeds', () async {
      final engine = FakeV2rayEngine();
      final service = VpnService(onStateChanged: (_, __) {}, engine: engine);
      service.setInitializedForTests(true);

      await expectLater(service.disconnect(), completes);
      expect(engine.stopV2RayCalls, 1);
    });
  });
}
