import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyre/services/android_vpn_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AndroidVpnService androidVpnService;

  setUp(() {
    androidVpnService = AndroidVpnService();
  });

  tearDown(() async {
    final channel = MethodChannel('com.vyre.vpn/android_vpn');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('isAlwaysOnVpnEnabled returns false when MethodChannel throws', () async {
    final channel = MethodChannel('com.vyre.vpn/android_vpn');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'error');
    });

    final result = await androidVpnService.isAlwaysOnVpnEnabled();
    expect(result, false);
  });

  test('requestAlwaysOnVpn returns false when MethodChannel throws', () async {
    final channel = MethodChannel('com.vyre.vpn/android_vpn');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'error');
    });

    final result = await androidVpnService.requestAlwaysOnVpn();
    expect(result, false);
  });

  test('isLockdownEnabled returns false when MethodChannel throws', () async {
    final channel = MethodChannel('com.vyre.vpn/android_vpn');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'error');
    });

    final result = await androidVpnService.isLockdownEnabled();
    expect(result, false);
  });

  test('isAlwaysOnVpnEnabled returns true when MethodChannel returns true', () async {
    final channel = MethodChannel('com.vyre.vpn/android_vpn');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return true;
    });

    final result = await androidVpnService.isAlwaysOnVpnEnabled();
    expect(result, true);
  });

  test('requestAlwaysOnVpn returns true when MethodChannel returns true', () async {
    final channel = MethodChannel('com.vyre.vpn/android_vpn');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return true;
    });

    final result = await androidVpnService.requestAlwaysOnVpn();
    expect(result, true);
  });

  test('isLockdownEnabled returns true when MethodChannel returns true', () async {
    final channel = MethodChannel('com.vyre.vpn/android_vpn');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      return true;
    });

    final result = await androidVpnService.isLockdownEnabled();
    expect(result, true);
  });
}
