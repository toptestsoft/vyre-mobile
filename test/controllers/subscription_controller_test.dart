import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:vyre/controllers/subscription_controller.dart';
import 'package:vyre/models/vpn_state.dart';
import 'package:vyre/services/subscription_cache.dart';
import 'package:vyre/services/vpn_service.dart';
import 'package:vyre/services/subscription_service.dart';

class FakeVpnService implements VpnService {
  @override
  final void Function(VpnState state, String rawState) onStateChanged;

  FakeVpnService(this.onStateChanged);

  @override
  Future<void> initialize() async {
    onStateChanged(VpnState.disconnected, 'DISCONNECTED');
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> connect({required String remark, required String config, List<String>? blockedApps}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<int> pingServer(String config) async => 100;

  @override
  void setInitializedForTests(bool value) {}

  @override
  bool get isInitialized => true;
}

class FakeSubscriptionServiceEmpty implements SubscriptionService {
  final SubscriptionCache cache;

  FakeSubscriptionServiceEmpty(this.cache);

  @override
  bool isSingleLink(String url) => false;

  @override
  Future<String> fetch(String url) async => 'invalid';

  @override
  List<V2RayURL> parseToV2RayUrls(String body, {required bool isSingleLink}) => <V2RayURL>[];

  @override
  ParseResult parse(String body, {required bool isSingleLink}) => const ParseResult(servers: []);

  @override
  V2RayURL parseOne(String line) => FlutterV2ray.parseFromURL('vless://test');
}

class FakeSubscriptionService implements SubscriptionService {
  final SubscriptionCache cache;

  FakeSubscriptionService(this.cache);

  @override
  bool isSingleLink(String url) => false;

  @override
  Future<String> fetch(String url) async => 'vless://test';

  @override
  List<V2RayURL> parseToV2RayUrls(String body, {required bool isSingleLink}) {
    return [FlutterV2ray.parseFromURL('vless://test')];
  }

  @override
  ParseResult parse(String body, {required bool isSingleLink}) => const ParseResult(servers: []);

  @override
  V2RayURL parseOne(String line) => FlutterV2ray.parseFromURL('vless://test');
}

void main() {
  group('SubscriptionController', () {
    late FakeVpnService fakeVpn;
    late FakeSubscriptionServiceEmpty fakeSubsEmpty;
    late TextEditingController inputController;

    setUp(() {
      fakeVpn = FakeVpnService((state, raw) {});
      fakeSubsEmpty = FakeSubscriptionServiceEmpty(SubscriptionCache());
      inputController = TextEditingController();
    });

    tearDown(() {
      inputController.dispose();
    });

    test('loadAndTest с валидной подпиской: vpnState переходит в testing, затем в disconnected с servers', () async {
      final fakeSubs = FakeSubscriptionService(SubscriptionCache());

      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: inputController,
        subscriptionService: fakeSubs,
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      expect(controller.vpnState, VpnState.initializing);
      await controller.initialize();
      expect(controller.vpnState, VpnState.disconnected);

      await controller.loadAndTest('https://example.com/sub');
      expect(controller.vpnState, VpnState.disconnected);
      expect(controller.servers.isNotEmpty, isTrue);
    });

    test('loadAndTest с невалидной подпиской: error устанавливается', () async {
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: inputController,
        subscriptionService: fakeSubsEmpty,
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      await controller.loadAndTest('invalid');
      expect(controller.error.isNotEmpty, isTrue);
      expect(controller.vpnState, VpnState.disconnected);
    });

    test('connect при пустом servers: error устанавливается', () async {
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: inputController,
        subscriptionService: fakeSubsEmpty,
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      await controller.connect(null);
      expect(controller.error, 'Нет серверов для подключения');
    });

    test('cancel во время тестирования: vpnState возвращается в disconnected', () async {
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: inputController,
        subscriptionService: fakeSubsEmpty,
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      await controller.cancel();
      expect(controller.vpnState, VpnState.disconnected);
      expect(controller.notice, 'Тестирование отменено');
    });

    test('dismissError очищает error', () async {
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: inputController,
        subscriptionService: fakeSubsEmpty,
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      await controller.initialize();
      await controller.loadAndTest('invalid');
      expect(controller.error.isNotEmpty, isTrue);
      controller.dismissError();
      expect(controller.error.isEmpty, isTrue);
    });

    test('notifyListeners вызываются при изменении состояния', () async {
      int notifyCount = 0;
      final controller = SubscriptionController(
        vpnService: fakeVpn,
        inputController: inputController,
        subscriptionService: fakeSubsEmpty,
        qrScannerBuilder: (_) => const SizedBox.shrink(),
      );

      controller.addListener(() => notifyCount++);
      await controller.initialize();
      expect(notifyCount, greaterThan(0));
    });
  });
}
