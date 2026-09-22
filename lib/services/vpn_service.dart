import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../models/vpn_state.dart';

abstract class V2rayEngine {
  Future<void> initializeV2Ray();
  Future<void> startV2Ray({required String remark, required String config, List<String>? blockedApps});
  Future<void> stopV2Ray();
  Future<int> getServerDelay({required String config});
  Future<bool> requestPermission();
  Future<int> getConnectedServerDelay();
}

class _FlutterV2rayAdapter implements V2rayEngine {
  _FlutterV2rayAdapter(this._v2ray);
  final FlutterV2ray _v2ray;

  @override
  Future<void> initializeV2Ray() => _v2ray.initializeV2Ray();

  @override
  Future<void> startV2Ray({required String remark, required String config, List<String>? blockedApps}) =>
      _v2ray.startV2Ray(remark: remark, config: config, blockedApps: blockedApps);

  @override
  Future<void> stopV2Ray() => _v2ray.stopV2Ray();

  @override
  Future<int> getServerDelay({required String config}) => _v2ray.getServerDelay(config: config);

  @override
  Future<bool> requestPermission() => _v2ray.requestPermission();

  @override
  Future<int> getConnectedServerDelay() => _v2ray.getConnectedServerDelay();
}

/// Единственная точка контакта с движком VPN.
class VpnService {
  VpnService({required this.onStateChanged, V2rayEngine? engine}) : _engine = engine;
  final void Function(VpnState state, String rawState) onStateChanged;
  V2rayEngine? _engine;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  void setInitializedForTests(bool value) => _initialized = value;

  Future<void> initialize() async {
    final v2ray = _engine ?? _FlutterV2rayAdapter(FlutterV2ray(
      onStatusChanged: (status) {
        onStateChanged(_mapState(status.state), status.state);
      },
    ));
    _engine = v2ray;
    try {
      await v2ray.initializeV2Ray().timeout(const Duration(seconds: 20));
      _initialized = true;
    } catch (e) {
      throw Exception('Не удалось запустить движок VPN. Перезапустите приложение.');
    }
  }

  Future<bool> requestPermission() => _engine!.requestPermission();

  Future<void> connect({
    required String remark,
    required String config,
    List<String>? blockedApps,
  }) async {
    try {
      await _engine!.startV2Ray(remark: remark, config: config, blockedApps: blockedApps)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception('VPN connect timeout or failed: $e');
    }
  }

  Future<void> disconnect() => _engine!.stopV2Ray();

  Future<int> pingServer(String config) async {
    try {
      return await _engine!.getServerDelay(config: config).timeout(const Duration(seconds: 5));
    } catch (_) {
      return -1;
    }
  }

  VpnState _mapState(String raw) => switch (raw) {
        'CONNECTED' => VpnState.connected,
        'CONNECTING' => VpnState.connecting,
        'DISCONNECTING' => VpnState.disconnecting,
        'DISCONNECTED' => VpnState.disconnected,
        _ => VpnState.disconnected, // CONNECTED_NOT и пр. не ломают состояние
      };
}
