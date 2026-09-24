import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:vyre/controllers/subscription_controller.dart';
import 'package:vyre/models/vpn_state.dart';
import 'package:vyre/services/subscription_cache.dart';
import 'package:vyre/services/vpn_service.dart';
import 'package:vyre/services/subscription_service.dart';

class FakeVpnService implements VpnService {
  // ignore: annotate_overrides
  void Function(VpnState state, String rawState) onStateChanged;
  final List<String> states = [];
  bool connectCallsStop = false;
  bool disconnectHangs = false;
  bool throwOnDisconnect = false;

  FakeVpnService(this.onStateChanged);

  @override
  Future<void> initialize() async {
    onStateChanged(VpnState.disconnected, 'DISCONNECTED');
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> connect({
    required String remark,
    required String config,
    List<String>? blockedApps,
  }) async {
    if (connectCallsStop) {
      onStateChanged(VpnState.connected, 'CONNECTED');
    }
  }

  @override
  Future<void> disconnect() async {
    if (throwOnDisconnect) {
      throw Exception('native disconnect failed');
    }
    if (disconnectHangs) {
      await Future.delayed(const Duration(days: 1));
    }
  }

  @override
  Future<int> pingServer(String config) async => 100;

  @override
  void setInitializedForTests(bool value) {}

  @override
  bool get isInitialized => true;
}

class FakeSubscriptionServiceConnectable implements SubscriptionService {
  final SubscriptionCache cache;

  FakeSubscriptionServiceConnectable(this.cache);

  // ignore: annotate_overrides
  bool isSingleLink(String url) => false;

  @override
  Future<String> fetch(String url) async => 'vless://test';

  @override
  List<V2RayURL> parseToV2RayUrls(String body, {required bool isSingleLink}) {
    return [FlutterV2ray.parseFromURL('vless://test')];
  }

  @override
  ParseResult parse(String body, {required bool isSingleLink}) =>
      const ParseResult(servers: []);

  @override
  V2RayURL parseOne(String line) => FlutterV2ray.parseFromURL('vless://test');
}

void main() {
  group('Regression: controller state races', () {
    test('CONNECTED during testing must not be lost', () async {
      final fakeVpn = FakeVpnService((state, raw) {});
      fakeVpn.connectCallsStop = true;
      final fakeSubs = FakeSubscriptionServiceConnectable(SubscriptionCache());
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: TextEditingController(text: 'https://example.com/sub'),
        subscriptionService: fakeSubs,
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      fakeVpn.onStateChanged = (state, raw) => controller.updateVpnState(state);

      final loadFuture = controller.loadAndTest('https://example.com/sub');
      await Future.delayed(const Duration(milliseconds: 50));
      fakeVpn.onStateChanged(VpnState.connected, 'CONNECTED');

      await loadFuture;

      expect(controller.vpnState, VpnState.connected,
          reason: 'Нативный CONNECTED во время testing должен сохраниться');
    });

    test('cancel during testing must prevent connect and stop native tunnel', () async {
      final fakeVpn = FakeVpnService((state, raw) {});
      fakeVpn.connectCallsStop = true;
      final fakeSubs = FakeSubscriptionServiceConnectable(SubscriptionCache());
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: TextEditingController(text: 'https://example.com/sub'),
        subscriptionService: fakeSubs,
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      fakeVpn.onStateChanged = (state, raw) => controller.updateVpnState(state);

      final loadFuture = controller.loadAndTest('https://example.com/sub');
      await Future.delayed(const Duration(milliseconds: 50));
      await controller.cancel();

      await loadFuture;

      expect(controller.vpnState, VpnState.disconnected);
      expect(controller.connectedServer, isNull,
          reason: 'cancel() должен сбрасывать connectedServer');
      expect(fakeVpn.states, isNot(contains('CONNECTED')),
          reason: 'cancel() не должен допускать вызов connect() и CONNECTED');
    });

    test('disconnect must complete even if native DISCONNECTED was already received', () async {
      final fakeVpn = FakeVpnService((state, raw) {});
      fakeVpn.disconnectHangs = false;
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: TextEditingController(text: 'https://example.com/sub'),
        subscriptionService: FakeSubscriptionServiceConnectable(SubscriptionCache()),
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      fakeVpn.onStateChanged = (state, raw) => controller.updateVpnState(state);
      controller.updateVpnState(VpnState.connected);
      fakeVpn.onStateChanged(VpnState.disconnected, 'DISCONNECTED');

      await expectLater(
        controller.disconnect(),
        completes,
        reason: 'disconnect() не должен зависать, если нативный DISCONNECTED уже пришел',
      );

      expect(controller.vpnState, VpnState.disconnected);
    });

    test('disconnect must not hang forever on native failure', () async {
      final fakeVpn = FakeVpnService((state, raw) {});
      fakeVpn.throwOnDisconnect = true;
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: TextEditingController(text: 'https://example.com/sub'),
        subscriptionService: FakeSubscriptionServiceConnectable(SubscriptionCache()),
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      fakeVpn.onStateChanged = (state, raw) => controller.updateVpnState(state);
      controller.updateVpnState(VpnState.connected);

      await expectLater(
        controller.disconnect(),
        completes,
        reason: 'disconnect() не должен зависать вечно даже если нативный вызов падает',
      );

      expect(controller.vpnState, VpnState.disconnected);
    });

    test('disconnect must complete within timeout even if native stop hangs', () async {
      final fakeVpn = FakeVpnService((state, raw) {});
      fakeVpn.disconnectHangs = true;
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: TextEditingController(text: 'https://example.com/sub'),
        subscriptionService: FakeSubscriptionServiceConnectable(SubscriptionCache()),
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      fakeVpn.onStateChanged = (state, raw) => controller.updateVpnState(state);
      controller.updateVpnState(VpnState.connected);

      await expectLater(
        controller.disconnect().timeout(const Duration(seconds: 6)),
        completes,
        reason: 'disconnect() должен завершиться по таймауту, если нативный stop зависает',
      );

      expect(controller.vpnState, VpnState.disconnected);
    });

    test('disconnect must not hang if native DISCONNECTED arrives first after resume', () async {
      final fakeVpn = FakeVpnService((state, raw) {});
      fakeVpn.disconnectHangs = true;
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: TextEditingController(text: 'https://example.com/sub'),
        subscriptionService: FakeSubscriptionServiceConnectable(SubscriptionCache()),
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      fakeVpn.onStateChanged = (state, raw) => controller.updateVpnState(state);
      controller.updateVpnState(VpnState.connected);

      // Симулируем возврат из фона: нативный сервис уже разорван,
      // но disconnect() вызывается позже и может зависнуть на stopV2Ray().
      fakeVpn.onStateChanged(VpnState.disconnected, 'DISCONNECTED');

      await expectLater(
        controller.disconnect().timeout(const Duration(seconds: 6)),
        completes,
        reason: 'disconnect() должен завершиться, если нативный DISCONNECTED уже пришел',
      );

      expect(controller.vpnState, VpnState.disconnected);
    });
  });
}
